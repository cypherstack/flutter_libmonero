#!/bin/bash

./build_iconv.sh
./build_boost.sh
./build_openssl.sh
./build_sodium.sh
./build_zmq.sh
./build_monero.sh
./copy_monero_deps.sh