artwork is available to download as packages for your game.
you can use `pesde` or `wally` to install the framework.
you can also download a binary from the github releases or build it yourself.

## From pesde (recommended)
1. Make sure you have [pesde](https://pesde.dev) installed.
2. Add the package
    ```
    pesde add ratplier/artwork
    ```
3. Import the package
    ```luau
    local art = require(ReplicatedStorage.roblox_packages.artwork)
    ```

## From wally
1. Make sure you have [wally](https://wally.run) installed.
2. Add the package
    ```
    artwork = "ratplier/artwork@1.0.0"
    ```
3. Import the package
    ```luau
    local art = require(ReplicatedStorage.Packages.artwork)
    ```

## From source
1. Clone the artwork repository
    ```luau
    git clone https://github.com/ratplier/artwork.git
    cd artwork
    ```
2. Install all tools
    ```luau
    rokit install
    ```
3. Build with rojo
    ```luau
    rojo build -o out/artwork.rbxm
    ```