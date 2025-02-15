#!/usr/bin/env bash

# Copyright (c) 2022 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -ex

function init() {
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NONE='\033[0m'

    REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}")/../" && pwd )"

    export PATH="/root/miniconda3/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/TensorRT-6.0.1.5/lib:$LD_LIBRARY_PATH"
}

function run_example_test {
    for exp in QuickStart DQN DQN_variant PPO SAC TD3 OAC DDPG MADDPG ES A2C
    do
        sed -i '/paddlepaddle/d' ./examples/${exp}/requirements*.txt
        sed -i '/parl/d' ./examples/${exp}/requirements*.txt
    done
    
    python -m pip install -r ./examples/QuickStart/requirements.txt
    python examples/QuickStart/train.py
    python -m pip uninstall -r ./examples/QuickStart/requirements.txt -y

    python -m pip install -r ./examples/DQN/requirements.txt
    python examples/DQN/train.py
    python -m pip uninstall -r ./examples/DQN/requirements.txt -y
    
    python -m pip install -r ./examples/DQN_variant/requirements.txt
    python examples/DQN_variant/train.py --train_total_steps 200 --warmup_size 100 --test_every_steps 50 --dueling True --env PongNoFrameskip-v4
    python -m pip uninstall -r ./examples/DQN_variant/requirements.txt -y
    
    python -m pip install -r ./examples/PPO/requirements_atari.txt
    python examples/PPO/train.py --train_total_steps 5000 --env PongNoFrameskip-v4
    python -m pip uninstall -r ./examples/PPO/requirements_atari.txt -y

    python -m pip install -r ./examples/PPO/requirements_mujoco.txt
    python examples/PPO/train.py --train_total_steps 5000 --env HalfCheetah-v4 --continuous_action
    python -m pip uninstall -r ./examples/PPO/requirements_mujoco.txt -y

    python -m pip install -r ./examples/SAC/requirements.txt
    python examples/SAC/train.py --train_total_steps 5000 --env HalfCheetah-v4
    python -m pip uninstall -r ./examples/SAC/requirements.txt -y
   
    python -m pip install -r ./examples/TD3/requirements.txt
    python examples/TD3/train.py --train_total_steps 5000 --env HalfCheetah-v4
    python -m pip uninstall -r ./examples/TD3/requirements.txt -y

    python -m pip install -r ./examples/OAC/requirements.txt
    python examples/OAC/train.py --train_total_steps 5000 --env HalfCheetah-v4
    python -m pip uninstall -r ./examples/OAC/requirements.txt -y
    
    python -m pip install -r ./examples/DDPG/requirements.txt
    python examples/DDPG/train.py --train_total_steps 5000 --env HalfCheetah-v4
    python -m pip uninstall -r ./examples/DDPG/requirements.txt -y
    
    xparl start --port 8837 --cpu_num 24
    python -m pip install -r ./examples/ES/requirements.txt
    python ./examples/ES/train.py --train_steps 2 --actor_num 24
    python -m pip uninstall -r ./examples/ES/requirements.txt -y
    xparl stop

    xparl start --port 8110 --cpu_num 5
    python -m pip install -r ./examples/A2C/requirements.txt
    python ./examples/A2C/train.py --max_sample_steps 50000
    python -m pip uninstall -r ./examples/A2C/requirements.txt -y
    xparl stop
    
    python -m pip install -r ./examples/MADDPG/requirements.txt
    python examples/MADDPG/train.py --max_episodes 21 --test_every_episodes 10
    python -m pip uninstall -r ./examples/MADDPG/requirements.txt -y
}

function print_usage() {
    echo -e "\n${RED}Usage${NONE}:
    ${BOLD}$0${NONE} [OPTION]"

    echo -e "\n${RED}Options${NONE}:
    ${BLUE}test${NONE}: run all unit tests
    ${BLUE}check_style${NONE}: run code style check
    "
}

function abort(){
    echo "Your change doesn't follow PaddlePaddle's code style." 1>&2
    echo "Please use pre-commit to check what is wrong." 1>&2
    exit 1
}

function check_style() {
    trap 'abort' 0
    set -e

    export PATH=/usr/bin:$PATH
    pre-commit install
    clang-format --version

    if ! pre-commit run -a ; then
        git diff
        exit 1
    fi

    trap : 0
}

function run_test_with_gpu() {
    unset CUDA_VISIBLE_DEVICES
    export FLAGS_fraction_of_gpu_memory_to_use=0.05
    
    mkdir -p ${REPO_ROOT}/build
    cd ${REPO_ROOT}/build

    if [ $# -eq 1 ];then
        cmake ..
    else
        cmake .. -$2=ON
    fi
    cat <<EOF
    ========================================
    Running unit tests with GPU...
    ========================================
EOF
    ctest --output-on-failure -j20
    cd ${REPO_ROOT}
    rm -rf ${REPO_ROOT}/build
}

function run_test_with_cpu() {
    export CUDA_VISIBLE_DEVICES=""

    mkdir -p ${REPO_ROOT}/build
    cd ${REPO_ROOT}/build
    if [ $# -eq 1 ];then
        cmake ..
    else
        cmake .. -$2=ON
    fi
    cat <<EOF
    =====================================================
    Running unit tests with CPU in the environment: $1
    =====================================================
EOF
    if [ "$#" == 2 ] && [ "$2" == "DIS_TESTING_SERIALLY" ]
    then
        ctest --output-on-failure 
    else
        ctest --output-on-failure -j20
    fi
    cd ${REPO_ROOT}
    rm -rf ${REPO_ROOT}/build
}

function run_import_test {
    export CUDA_VISIBLE_DEVICES=""

    mkdir -p ${REPO_ROOT}/build
    cd ${REPO_ROOT}/build

    cmake .. -DIS_TESTING_IMPORT=ON

    cat <<EOF
    ========================================
    Running import test...
    ========================================
EOF
    ctest --output-on-failure
    cd ${REPO_ROOT}
    rm -rf ${REPO_ROOT}/build
}


function main() {
    set -e
    local CMD=$1
    
    init
    case $CMD in
        check_style)
            check_style
            ;;
        test)
            # test code compability in environments with various python versions
            declare -a envs=("py39" "py36" "py37" "py38")
            for env in "${envs[@]}";do
                export PATH="/root/miniconda3/bin:$PATH"
                source activate $env
                python -m pip install --upgrade pip
                echo ========================================
                echo Running tests in $env ..
                echo `which pip`
                echo ========================================
                pip config set global.index-url https://mirror.baidu.com/pypi/simple
                pip install .
                if [ \( $env == "py39" -o $env == "py36" -o $env == "py37" -o $env == "py38" \) ]
                then
                    run_import_test # import parl test

                    pip install -r .teamcity/requirements.txt
                    pip install paddlepaddle==2.3.1
                    run_test_with_cpu $env
                    # uninstall paddlepaddle when testing remote module
                    pip uninstall -y paddlepaddle
                    run_test_with_cpu $env "DIS_TESTING_SERIALLY"
                    run_test_with_cpu $env "DIS_TESTING_REMOTE"
                else
                    echo ========================================
                    echo "in torch environment"
                    echo ========================================
                    pip install -r .teamcity/requirements_torch.txt
                    run_test_with_cpu $env "DIS_TESTING_TORCH"
                fi
                # clean env
                export LC_ALL=C.UTF-8
                export LANG=C.UTF-8
                xparl stop
            done

            pip install -r .teamcity/requirements.txt
            pip install /data/paddle_package/paddlepaddle_gpu-2.3.1-cp38-cp38-manylinux1_x86_64.whl
            run_test_with_gpu $env

            ;;
        example)
            # run example test in env test_example(python 3.8)
            pip config set global.index-url https://mirror.baidu.com/pypi/simple
            declare -a test_example_env='test_example'
            source activate $test_example_env
            pip install .
            pip install /data/paddle_package/paddlepaddle_gpu-2.3.1-cp38-cp38-manylinux1_x86_64.whl
            run_example_test
            ;;
        *)
            print_usage
            exit 0
            ;;
    esac
    echo "finished: ${CMD}"
}

main $@
