#! /bin/bash

# Confirm that the current directory name is "ai".
if [[ ! $(basename "$PWD") == "ai" ]]; then
    echo "Error: This script must be run from the 'ai' directory."
    exit 1
fi

# Identify the output files.
version=$(< version.json jq -r .version)
checksums_file=$(realpath .sha256sum.txt)
package_file=$(realpath ../GenshiAI-$version.zip)
package_checksum_file=$package_file.sha256sum.txt

# Confirm the operation with the user.
echo "This will remove and then create the following files:

  - $checksums_file
  - $package_file
  - $package_checksum_file
"
read -p "Is this correct? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

# Remove any preexisting output files.
echo
rm -fv $checksums_file $package_file $package_checksum_file

# Create the checksums file.
echo
IFS=$'\n'
files=$(find -type f -printf "%P\n")
sha256sum $files | tee $checksums_file || {
    echo "Failed to create $checksums_file."
    exit 1
}

# Create the package file.
echo
pushd .. > /dev/null
7z a -mx9 $package_file ai || {
	popd > /dev/null
	echo "Failed to create $package_file."
	exit 1
}
popd > /dev/null

# Create the package checksum file.
echo
sha256sum $package_file | tee $package_checksum_file || {
    echo "Failed to create $package_checksum_file."
    exit 1
}
