# Caravel Simple FPU
Electric Project by Jesús Jiménez :)
EIE-UCR, December 2024
RTL from: https://github.com/Desrep/simple_fpu



## Run Project

### Prerequisites
- Python 3.8+ with PIP
- Docker

### Setup Enviroment
- Clone repo
```
git clone <repo URL>
```

- Setup tools
```
make setup
make precheks
```

### Build Project
- Generate physical design
```
make fpu
make user_project_wrapper
```

### Run Simulations
- Generate verification reports and waveforms

```
make caravel-cocotb
make caravel-cocotb

# View waveforms
gtkwave verilog/dv/cocotb/sim/
gtkwave verilog/dv/cocotb/sim/
```

If the simulations don't run, change STAGES=6 to STAGES=1 in divide_r.v and sqrt.v (line 21 and line 23, respectively).


### Run MPW-Precheck
```
make run-precheck
```


## Interfaces Mapping




## RTL verification with SystemVerilog UVM





Refer to [README](docs/source/index.md) for this sample project documentation.
