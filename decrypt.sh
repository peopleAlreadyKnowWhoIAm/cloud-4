#! /bin/bash

gpg --quiet --batch --yes --decrypt --passphrase="$SECRET_PASSPHRASE" --output key.json key.json.gpg
gpg --quiet --batch --yes --decrypt --passphrase="$SECRET_PASSPHRASE" --output variables.tf variables.tf.gpg
