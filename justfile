bin_dir := "bin"
exe := "holiday_havok"

build:
    odin build . -out:{{bin_dir}}/{{exe}}

run: build
    ./{{bin_dir}}/{{exe}}
