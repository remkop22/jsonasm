# jsonasm
JSON validator written in x86 assembly. 

### Why?
I wrote this purely to better my own understanding of lower level langauges. Please do not use this.

### Usage:
* Build the executable with the build script.

  ```bash
  $ ./build.sh jsonasm.asm
  ```
* Run it with the included valid test file or other json file.

  ```bash
  $ ./build/jsonasm test/valid.json
  ```
  ```bash
  JSON is valid!
  ```
* Or run it with invalid json.
  ```bash
  $ ./build/jsonasm test/invalid1.json
  ```
  ```bash
  {"float":12.34"another float":43.21}
  expected '}' at index 14 but found '"'
  ```
