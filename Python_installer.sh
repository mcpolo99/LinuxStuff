#!/bin/bash

# Function to check and install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    sudo apt update
    sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
        libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
        libncursesw5-dev xz-utils tk-dev liblzma-dev python3-openssl \
        git libffi-dev libgdbm-dev libnss3-dev libssl-dev
}

# Function to fetch available Python versions from the FTP server
fetch_python_versions() {
    # Fetch available versions from the Python FTP server
    echo "Fetching available Python versions..."
    versions=$(curl -s https://www.python.org/ftp/python/ | \
               grep -oP 'href="(\d+\.\d+(\.\d+)*)/"' | \
               sed 's/href="//' | sed 's/"//' | sort -V)

    # If no versions are found, show an error
    if [[ -z "$versions" ]]; then
        echo "No Python versions found on the FTP server."
        exit 1
    fi

    # Display available versions to the user
    echo "Available Python versions:"
    select version in $versions; do
        if [[ -n "$version" ]]; then
            selected_version=$(echo "$version" | sed 's/\/$//')
            echo "You selected version: $selected_version"
            break
        else
            echo "Invalid selection. Please choose a valid version."
        fi
    done
}

# Function to check if the selected version is already installed
check_installed_version() {
    installed_version=$(python3 --version 2>&1 | grep -oP '\d+\.\d+(\.\d+)*')

    if [[ -n "$installed_version" ]]; then
        echo "Currently installed Python version: $installed_version"
        # Compare the middle parts of the version numbers
        installed_middle=$(echo $installed_version | cut -d. -f1,2)
        selected_middle=$(echo $selected_version | cut -d. -f1,2)

        if [[ "$installed_middle" == "$selected_middle" && "$installed_version" != "$selected_version" ]]; then
            echo "Warning: A version with the same middle version (e.g., $installed_middle) is already installed."
            read -p "Do you want to uninstall the existing version before installing $selected_version? (y/n): " choice
            if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
                sudo apt-get remove -y python$installed_version
                echo "$installed_version uninstalled."
            fi
        fi
    fi
}

# Function to download and install Python from FTP
install_python_from_ftp() {
    echo "Downloading and installing Python $selected_version..."
    # Download the selected Python version from the FTP server
    download_url="https://www.python.org/ftp/python/$selected_version/Python-$selected_version.tgz"
    wget $download_url

    # Extract the downloaded tarball
    tar -xvzf "Python-$selected_version.tgz"
    cd "Python-$selected_version"

    # Configure, compile, and install Python
    ./configure --enable-optimizations
    make -j$(nproc)

    # If the version is different (e.g., 3.12.x and 3.13.x), we use altinstall
    if [[ "$installed_middle" != "$selected_middle" ]]; then
        sudo make altinstall
    else
        sudo make install
    fi

    # Clean up
    cd ..
    rm -rf "Python-$selected_version" "Python-$selected_version.tgz"

    # Verify installation
    python$(echo $selected_version | cut -d. -f1,2) --version
}

# Main function to orchestrate the installation
main() {
    # Install required dependencies
    install_dependencies

    # Fetch available versions and allow the user to select one
    fetch_python_versions

    # Check if the selected version is already installed
    check_installed_version

    # Ask the user if they want to proceed with the installation
    read -p "Do you want to install Python $selected_version? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        # Proceed with the installation
        install_python_from_ftp
    else
        echo "Installation aborted."
    fi
}

# Run the main function
main
