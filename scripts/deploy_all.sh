
source ../.env


# 1 . DEPLOY SAFE
echo "🚀 Declaring and deploying Safe…"
./safe/declare_and_deploy.sh

sleep 20

#2. DEPLOY CONTROLLER
echo "🚀 Declaring and deploying Controller…"
./controller/declare_and_deploy.sh

sleep 20

#3 SET CONTROLLER AS OPERATOR OF SAFE
echo "🚀 Setting Controller as Operator of Safe…"
./safe/set_controller.sh

