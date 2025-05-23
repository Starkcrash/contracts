console.log('Script starting...'); // Log right at the beginning

import {
  Account,
  RpcProvider,
  CallData,
  constants,
  shortString,
  TransactionReceipt,
  TransactionStatus,
  InvokeTransactionReceiptResponse,
  Contract,
  num,
  RPC,
  ETH_ADDRESS,
  CairoFixedArray,
  cairo,
} from 'starknet';
import { config } from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { ABI } from './rouletteABI.js';

// Calculate __dirname equivalent in ES module scope
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables from .env file
try {
  console.log(
    `Attempting to load .env file from: ${path.resolve(
      __dirname,
      '../../.env'
    )}`
  );
  config({ path: path.resolve(__dirname, '../../.env') });
  console.log('.env file loaded successfully (or did not crash).');
  // Optionally log loaded vars to check
  // console.log('RPC_URL loaded:', process.env.RPC_URL ? 'Yes' : 'No');
} catch (error) {
  console.error('Error loading .env file:', error);
  // Decide if you want to exit or continue with potentially missing vars
  process.exit(1);
}

// --- Configuration ---
// VRF Provider address (Sepolia) from Cartridge docs
const VRF_PROVIDER_ADDRESS =
  '0x051fea4450da9d6aee758bdeba88b2f665bcbf549d2c61421aa724e9ac0ced8f';

// !! Replace with your deployed Roulette contract address !!
const ROULETTE_CONTRACT_ADDRESS =
  process.env.ROULETTE_CONTRACT_ADDRESS || 'YOUR_ROULETTE_CONTRACT_ADDRESS';

// Updated entrypoint name based on user confirmation
const ROULETTE_CONSUME_ENTRYPOINT = 'play_game';

const RPC_URL = process.env.RPC_URL;
const OPERATOR_ADDRESS = process.env.OPERATOR_ADDRESS;
const OPERATOR_PRIVATE_KEY = process.env.PK;
const CONTROLLER_CONTRACT_ADDRESS = process.env.CONTROLLER_CONTRACT_ADDRESS;

const DEFAULT_RETRY_INTERVAL = 5000; // 5 seconds
const TIMEOUT = 180000; // 3 minutes

// --- Define Bet Structure (based on Cairo definition) ---
// Note: Adapt types (e.g., number vs string for u256/felt252) as needed for your specific contract ABI/expectations
interface Bet {
  bet_type: number; // Assuming enum maps to numbers: 0=Straight, 1=Red/Black, 2=Even/Odd, 3=Column, 4=Dozen, 5=High/Low
  bet_value: number; // Value associated with the type (e.g., 0 for Red, 1 for Black)
  amount: string; // u256 as string (e.g., '1' for 1 wei)
  game_id: number; // u64
  user_address: string; // ContractAddress
  split_bet: boolean;
  split_bet_value: number[]; // Array<u64>
  corner_bet: boolean;
  corner_bet_value: number[]; // Array<u64>
}

// --- Helper Functions ---
function validateEnvironment() {
  const missing: string[] = [];
  if (!RPC_URL) missing.push('RPC_URL');
  if (!OPERATOR_ADDRESS) missing.push('OPERATOR_ADDRESS');
  if (!OPERATOR_PRIVATE_KEY) missing.push('OPERATOR_PRIVATE_KEY');
  if (ROULETTE_CONTRACT_ADDRESS === 'YOUR_ROULETTE_CONTRACT_ADDRESS') {
    console.warn(
      'Warning: ROULETTE_CONTRACT_ADDRESS is not set in environment or script. Using placeholder.'
    );
  }
  if (missing.length > 0) {
    throw new Error(`Missing environment variables: ${missing.join(', ')}`);
  }
}

// Type guard to check if the receipt is InvokeTransactionReceiptResponse
function isInvokeReceipt(
  receipt: any
): receipt is InvokeTransactionReceiptResponse {
  return (
    receipt &&
    typeof receipt.execution_status !== 'undefined' &&
    typeof receipt.finality_status !== 'undefined'
  );
}

async function getTransactionStatus(
  provider: RpcProvider,
  receipt: InvokeTransactionReceiptResponse
): Promise<TransactionStatus> {
  try {
    // Starknet.js v6 uses execution_status and finality_status
    if (receipt.execution_status === 'REVERTED') {
      return TransactionStatus.REJECTED;
    }
    if (receipt.finality_status === 'ACCEPTED_ON_L2') {
      return receipt.execution_status === 'SUCCEEDED'
        ? TransactionStatus.ACCEPTED_ON_L2
        : TransactionStatus.REJECTED;
    }
    // Handle other finality statuses if needed, default to RECEIVED if still processing
    if (receipt.finality_status === 'ACCEPTED_ON_L1') {
      return TransactionStatus.ACCEPTED_ON_L1;
    }
    // If not final or reverted, consider it received/pending
    return TransactionStatus.RECEIVED;
  } catch (error) {
    console.error('Error checking transaction status:', error);
    throw error;
  }
}

async function waitForTx(
  provider: RpcProvider,
  txHash: string
): Promise<InvokeTransactionReceiptResponse> {
  console.log(`Waiting for transaction: ${txHash}`);
  const startTime = Date.now();

  while (Date.now() - startTime < TIMEOUT) {
    let receipt: unknown;
    try {
      // Use getTransactionReceipt which returns different types based on tx version/status
      receipt = await provider.getTransactionReceipt(txHash);

      if (!receipt || !isInvokeReceipt(receipt)) {
        // If no receipt or not the expected type yet, wait and retry
        console.log(
          `Transaction ${txHash} receipt not available or not invoke type yet. Waiting...`
        );
        await new Promise((resolve) =>
          setTimeout(resolve, DEFAULT_RETRY_INTERVAL)
        );
        continue;
      }

      // Now we know receipt is InvokeTransactionReceiptResponse
      const status = await getTransactionStatus(provider, receipt);

      switch (status) {
        case TransactionStatus.ACCEPTED_ON_L2:
          console.log(`Transaction ${txHash} accepted on L2.`);
          return receipt;
        case TransactionStatus.ACCEPTED_ON_L1: // Also final
          console.log(`Transaction ${txHash} accepted on L1.`);
          return receipt;
        case TransactionStatus.REJECTED:
          console.error(
            `Transaction ${txHash} rejected. Status: ${receipt.execution_status}, ${receipt.finality_status}`
          );
          // Attempt to access revert_reason if available (may not be on all rejected types)
          const revertReason = (receipt as any).revert_reason;
          if (revertReason) {
            console.error(`Revert reason: ${revertReason}`);
          }
          throw new Error(`Transaction ${txHash} rejected.`);
        case TransactionStatus.RECEIVED: // Still processing
          console.log(`Transaction ${txHash} status: ${status}. Waiting...`);
          break;
        default:
          // This case handles potential future statuses or unexpected states
          console.log(
            `Transaction ${txHash} has status: ${status}. Waiting...`
          );
      }
    } catch (error: any) {
      // Check specifically for Transaction hash not found error
      if (
        error.message &&
        error.message.includes('Transaction hash not found')
      ) {
        console.log(`Transaction ${txHash} not found yet. Waiting...`);
      } else {
        // Log other errors, might be network issues, RPC errors, etc.
        console.error(
          `Error fetching receipt or checking status for ${txHash}:`,
          error
        );
        // Optionally add more robust error handling or retries based on error type
      }
    }
    // Wait before the next poll
    await new Promise((resolve) => setTimeout(resolve, DEFAULT_RETRY_INTERVAL));
  }

  // If the loop finishes without returning, it's a timeout
  throw new Error(
    `Transaction ${txHash} timed out after ${TIMEOUT / 1000} seconds.`
  );
}

// --- Main Test Function ---
async function testSpinRoulette() {
  validateEnvironment();

  if (!RPC_URL || !OPERATOR_ADDRESS || !OPERATOR_PRIVATE_KEY) {
    // This check is redundant due to validateEnvironment, but satisfies TS compiler
    throw new Error('Environment variables checked again and are missing.');
  }

  const provider = new RpcProvider({ nodeUrl: RPC_URL });
  console.log('Provider initialized');

  const account = new Account(
    provider,
    OPERATOR_ADDRESS,
    OPERATOR_PRIVATE_KEY,
    '1',
    '0x3'
  ); // Using cairo1
  console.log('Account initialized');

  // We need the contract ABI to make view calls like get_current_game
  // For now, assuming a minimal ABI or using callContract directly.
  // If you have the full ABI JSON, load it here for type safety.
  const rouletteContract = new Contract(
    ABI,
    ROULETTE_CONTRACT_ADDRESS,
    provider
  );
  rouletteContract.connect(account); // Connect account for sending transactions
  console.log('Roulette contract instance created');

  console.log(`Using account: ${account.address}`);
  console.log(`Using Roulette contract: ${ROULETTE_CONTRACT_ADDRESS}`);
  console.log(`Using VRF Provider: ${VRF_PROVIDER_ADDRESS}`);

  try {
    // --- Get Current Game ID for Salt ---
    let currentGameId: number;
    try {
      console.log(`Fetching current game ID for player: ${account.address}...`);
      const currentGameIdRaw = await rouletteContract.call('get_current_game', [
        account.address, // player argument
      ]);
      console.log('Raw currentGameId received:', currentGameIdRaw);
      // Assuming the result is a single bigint or can be converted
      // Convert bigint to number for use as salt (ensure game ID doesn't exceed JS number limits)
      currentGameId = Number(currentGameIdRaw);
      console.log(`Current game ID for ${account.address}: ${currentGameId}`);
    } catch (error) {
      console.error('Error fetching current game ID:', error); // Specific error for this call
      throw error; // Re-throw to be caught by the outer handler
    }

    // --- Construct Calls ---
    const betAmount = 10000000000000n;

    // 1. Construct the request_random call using Source::Salt(game_id)
    console.log(`Using game ID ${currentGameId} as salt for VRF request.`);
    const requestRandomCall = {
      contractAddress: VRF_PROVIDER_ADDRESS,
      entrypoint: 'request_random',
      calldata: CallData.compile({
        caller: ROULETTE_CONTRACT_ADDRESS,
        source: {
          type: 0,
          salt: account.address,
        },
      }),
    };

    // 2. Construct the call to the roulette contract's play_game entrypoint
    // Create a sample high-level bet object
    const sampleBet = {
      game_id: 0, // Match the current game ID
      user_address:
        '0x05598089625602DB226A2149c5B2E47D985e56c5201007707B5623C146896295', // The player placing the bet
      bet_type: 1, // Bet on Red/Black
      bet_value: 0, // 0 for Red
      amount: cairo.uint256(betAmount), // Use BigInt for u256 amount
      split_bet: false,
      split_bet_value: CairoFixedArray.compile([0, 0]),
      corner_bet: false,
      corner_bet_value: CairoFixedArray.compile([0, 0, 0, 0]),
    };
    console.log('Sample bet:', sampleBet);

    // Use populate to generate the call object with correct calldata
    console.log('Populating play_game call with sample bet...');
    const consumeCall = rouletteContract.populate('play_game', {
      bet: [sampleBet],
    });
    console.log('Populated play_game call:', consumeCall);

    const multiCall = [requestRandomCall, consumeCall];

    // --- Estimate Fee and Resource Bounds for V3 Transaction ---
    console.log('Estimating fee and resource bounds for V3 transaction...');
    // Pass the populated multicall to estimateInvokeFee
    const feeEstimation = await account.estimateInvokeFee(multiCall, {
      version: 3,
      feeDataAvailabilityMode: RPC.EDataAvailabilityMode.L1,
    });

    console.log('Fee Estimation Result:', feeEstimation);
    console.log('Estimated Resource Bounds:', feeEstimation.resourceBounds);
    console.log('Suggested Max Fee (for info):', feeEstimation.suggestedMaxFee);

    // 3. Execute the multicall using estimated bounds and V3 parameters
    console.log(
      `Executing V3 multicall with estimated bounds: request_random -> ${ROULETTE_CONSUME_ENTRYPOINT}`
    );
    const multiCallTx = await account.execute(
      multiCall, // Use the defined multicall array,
      {
        version: 3,
        feeDataAvailabilityMode: RPC.EDataAvailabilityMode.L1,
        resourceBounds: feeEstimation.resourceBounds, // Use estimated bounds
      }
    );

    console.log(`Transaction hash: ${multiCallTx.transaction_hash}`);

    // 4. Wait for the transaction to be accepted
    const receipt = await waitForTx(provider, multiCallTx.transaction_hash);

    if ('actual_fee' in receipt && receipt.actual_fee) {
      console.log(
        `Transaction successful! Actual Fee: ${JSON.stringify(
          receipt.actual_fee
        )}`
      );
    } else {
      console.log(
        'Transaction successful! (Actual fee details not available in this receipt type)'
      );
    }
    // console.log(
    //   'Receipt:',
    //   JSON.stringify(
    //     receipt,
    //     (key, value) => (typeof value === 'bigint' ? value.toString() : value),
    //     2
    //   )
    // );
  } catch (error) {
    console.error('Error executing VRF test transaction:');
    if (error instanceof Error) {
      console.error(error.message);
    } else {
      console.error('Raw error object:', error); // Log the raw error object for more details
    }
    process.exit(1); // Exit with error code
  }
}

// --- Run the Test ---
testSpinRoulette();
