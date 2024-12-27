bin_dir := "bin"
exe := "christmas-catch"

build:
    odin build . -out:{{bin_dir}}/{{exe}}

run: build
    ./{{bin_dir}}/{{exe}}
