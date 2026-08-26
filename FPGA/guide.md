# VHDL Boilerplate Generator Cheat Sheet

## Run

```bash
python vhdl_boilerplate_gen.py design.json --out .
```

Multiple JSON files:

```bash
python vhdl_boilerplate_gen.py common.json design.json --out .
```

---

## JSON Structure

```json
{
  "top_directory": {
    "sub_directory": {
      "file_name.vhd": {
        "generics": [
          {"name": "WIDTH", "type": "positive", "default": 8}
        ],
        "ports": [
          {"name": "clk", "dir": "in",  "type": "bit"},
          {"name": "rst", "dir": "in",  "type": "bit"},
          {"name": "a",   "dir": "in",  "type": "vector WIDTH bits"},
          {"name": "b",   "dir": "in",  "type": "vector WIDTH bits"},
          {"name": "y",   "dir": "out", "type": "vector WIDTH bits"}
        ],
        "components": ["alu", "mux"]
      }
    }
  }
}
```

---

## Example

```json
{
  "rtl": {
    "components": {
      "alu.vhd": {
        "ports": [
          {"name": "a",    "dir": "in",  "type": "vector 8 bits"},
          {"name": "b",    "dir": "in",  "type": "vector 8 bits"},
          {"name": "op",   "dir": "in",  "type": "vector 4 bits"},
          {"name": "y",    "dir": "out", "type": "vector 8 bits"},
          {"name": "zero", "dir": "out", "type": "bit"}
        ]
      }
    },

    "top_level": {
      "datapath.vhd": {
        "generics": [
          {"name": "WIDTH", "type": "positive", "default": 8}
        ],
        "ports": [
          {"name": "clk",  "dir": "in",  "type": "bit"},
          {"name": "rst",  "dir": "in",  "type": "bit"},
          {"name": "din",  "dir": "in",  "type": "vector WIDTH bits"},
          {"name": "dout", "dir": "out", "type": "vector WIDTH bits"}
        ],
        "components": ["alu"]
      }
    }
  }
}
```

Output:

```txt
./rtl/components/alu.vhd
./rtl/top_level/datapath.vhd
```

---

## Entity Name

Entity name comes from the file name:

```txt
alu.vhd       -> entity alu
datapath.vhd  -> entity datapath
```

---

## Types

```txt
bit                 -> std_logic
vector 8 bits       -> std_logic_vector(7 downto 0)
vector WIDTH bits   -> std_logic_vector(WIDTH-1 downto 0)
unsigned 8 bits     -> unsigned(7 downto 0)
signed 8 bits       -> signed(7 downto 0)
int                 -> integer
nat                 -> natural
bool                -> boolean
positive            -> positive
vhdl:<raw type>     -> raw VHDL type
```

Raw VHDL type example:

```json
{"name": "state", "dir": "in", "type": "vhdl:my_state_type"}
```

---

## Components

```json
"components": ["alu", "mux"]
```

Components can be defined before or after the entity using them.

The script searches all JSON files globally first.

It generates:

- component declaration
- commented instantiation template

Example generated template:

```vhdl
-- U_alu : alu
--   port map (
--     a => ,
--     b => ,
--     op => ,
--     y => ,
--     zero =>
--   );
```

---

## Safe Edit Zones

Manual code is preserved inside:

```vhdl
-- USER SIGNALS BEGIN
-- USER SIGNALS END

-- USER CONNECTIONS BEGIN
-- USER CONNECTIONS END

-- USER LOGIC BEGIN
-- USER LOGIC END
```

You can rerun the script without losing code inside those blocks.