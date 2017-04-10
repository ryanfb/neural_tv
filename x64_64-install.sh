#!/bin/bash

DATASET="${DATASET_SRC}"
MODEL="$1"
IMAGES="$2"

. /opt/neural-networks/torch/install/bin/torch-activate

# Assuming the last bit of the URL is the file
SEP="/"
L=$(expr $(grep -o "${SEP}" <<< "${DATASET_SRC}" | wc -l) + 1)
FILE=$(echo "${DATASET_SRC}" | cut -f"${L}" -d"${SEP}")

# Install dataset
cd "${MODEL}"
FIRST_RUN=$(find /data/model/ -name '*.t7')

if [ ! -f "${FIRST_RUN}" ]
then 
	wget -c "${DATASET_SRC}"
	unzip "${FILE}" && rm -f "${FILE}"
fi

MODEL="$(find /data/model -name '*.t7')"

# Run command
cd /opt/neural-networks/neuraltalk2
timeout -k 12m 10m /opt/neural-networks/torch/install/bin/th eval.lua \
	-model "${MODEL}" \
	-image_folder "${IMAGES}" \
	-num_images -1 \
	-gpuid -1 && cp -rv vis "${IMAGES}/vis"
