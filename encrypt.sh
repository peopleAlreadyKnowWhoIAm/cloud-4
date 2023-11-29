#! /bin/bash

gpg --quiet --batch --yes --symmetric --cipher-algo AES256 --passphrase="$SECRET_PASSPHRASE" --output key.json.gpg key.json
gpg --quiet --batch --yes --symmetric --cipher-algo AES256 --passphrase="$SECRET_PASSPHRASE" --output variables.tf.gpg variables.tf
