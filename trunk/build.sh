#!/bin/bash
if [ $# -lt 1 ]
then
	echo "Usage: $0 [-emu] <name>"
	exit 1
fi

if [ $1 == "-emu" ]
then
	echo "building with device emulation"
	nvcc $2 --device-emulation -I ~/NVIDIA_GPU_Computing_SDK/C/common/inc/ -L ~/NVIDIA_GPU_Computing_SDK/C/lib/ -lcutil -arch=sm_11
else
	echo "building for hardware"
	nvcc $1 -I ~/NVIDIA_GPU_Computing_SDK/C/common/inc/ -L ~/NVIDIA_GPU_Computing_SDK/C/lib/ -lcutil -arch=sm_11
fi
