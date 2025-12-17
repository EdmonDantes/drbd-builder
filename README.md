# DRBD Builder

This project helps to build [DRBD kernel module](https://github.com/LINBIT/drbd)
and [DRBD utils](https://github.com/LINBIT/drbd-utils) mostly for Debian-based systems (Debian, Ubuntu, etc.).

## Features

- Using Docker to build DRBD and don't pollute your system.
- Configure APT proxy repository
- Installation all required dependencies for building.
- Compile Coccinelle instead of installing it from repository.

## Usage

Run docker container to start building and don't pollute your system.
You can use tag `debian` or `ubuntu` for different distributions.

```bash
docker run --rm \
-v $(pwd)/result:/result \
-e DRBD_BUILDER_COCCINELE_ENABLED_BUILD=on \
-e DRBD_BUILDER_DRBD_KERNEL_MODULE_ENABLED_BUILD=on \
-e DRBD_BUILDER_DRBD_UTILS_ENABLED_BUILD=on \
-e DRBD_BUILDER_RESULT_UID=$(id -u) \
-e DRBD_BUILDER_RESULT_GUID=$(id -g) \
dantes2104/drbd-builder:debian
```

Script create two folders:

- `/result/kernel/module` - DRBD Kernel Module
- `/result/utils` - DRBD Utils

### After building

You can install and load DRBD Kernel Module with commands below:

```bash
sudo mkdir -p /lib/modules/$(uname -r)/kernel/drivers/block/drbd && \ 
cp $(pwd)/result/kernel/module/* /lib/modules/$(uname -r)/kernel/drivers/block/drbd && \
depmod -a && \
modprobe drbd
```

## Configuration

| Variable name                                   | Description                                                                                                     | Possible values                     |
|-------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|-------------------------------------|
| `DRBD_BUILDER_LOG_LEVEL`                        | Level of logging                                                                                                | `debug`, `info`, `warning`, `error` |
| `DRBD_BUILDER_APT_HTTP_PROXY`                   | Proxy for installing dependencies for HTTP repositories                                                         |                                     |
| `DRBD_BUILDER_APT_HTTPS_PROXY`                  | Proxy for installing dependencies for HTTPS repositories                                                        |                                     |
| `DRBD_BUILDER_COCCINELE_ENABLED_BUILD`          | Building Coccinele instead of installing from repository (Required for DRBD Kernel Module)                      | `on`, `yes`, `true`                 |
| `DRBD_BUILDER_COCCIENELE_ENABLED_INSTALL`       | Installing Coccinele from repository instead of building (may be produce errors on building DRBD Kernel Module) |                                     |
| `DRBD_BUILDER_COCCINELE_VERSION`                | Version of Coccinele to build (git tag in official repository)                                                  |                                     |
| `DRBD_BUILDER_DRBD_KERNEL_MODULE_ENABLED_BUILD` | Enable building DRBD Kernel Module                                                                              | `on`, `yes`, `true`                 |
| `DRBD_BUILDER_DRBD_KERNEL_MODULE_VERSION`       | Version of DRBD Kernel Module (git tag in official repository)                                                  |                                     |
| `DRBD_BUILDER_DRBD_UTILS_ENABLED_BUILD`         | Enable building DRBD Utils                                                                                      |                                     |
| `DRBD_BUILDER_DRBD_UTILS_VERSION`               | Version of DRBD Utils (git tag in official repository)                                                          |                                     |
| `DRBD_BUILDER_RESULT_UID`                       | Owner of result folder and files inside                                                                         | one of possible value is `$(id -u)` |
| `DRBD_BUILDER_RESULT_GUID`                      | Owner group of result folder and files inside                                                                   | one of possible value is `$(id -g)` |