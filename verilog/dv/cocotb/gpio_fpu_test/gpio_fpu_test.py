# SPDX-FileCopyrightText: 2024 jjimenezu

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SPDX-License-Identifier: Apache-2.0

from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb 
@cocotb.test() # cocotb test marker
@report_test # wrapper for configure test reporting files
async def gpio_fpu_test(dut):
    caravelEnv = await test_configure(dut, timeout_cycles=1000000000) #configure, start up and reset caravel

    # Select: LA mode
    # caravelEnv.drive_gpio_in((37,35),0b000)
    caravelEnv.drive_gpio_in((34,32),0b001)

    # Handshake
    await caravelEnv.release_csb()
    await caravelEnv.wait_mgmt_gpio(0)

    # Initial Monitor
    gpios_value_str = caravelEnv.monitor_gpio(37, 32).binstr
    cocotb.log.info (f"Control:    IO[37:32] = '{gpios_value_str}'")
    gpios_value_str = caravelEnv.monitor_gpio(31, 0).binstr
    cocotb.log.info (f"Switchable: IO[31:0]  = '{gpios_value_str}'")

    # Reference Data
    in1 = [
          0x43187d07, 0xc41ba642,
          0x43765d11, 0xc3010b01,
          0xc38dc2c6, 0xc441751b,
          0x4363dfa8, 0x43311bc1, 0xc3fb5d7a
          ]
    
    in2 = [
          0x439af94e, 0x431292e9,
          0xc4425485, 0xc326b2ff,
          0xc3983be4, 0x436611ec,
          0x00000000, 0x00000000, 0x00000000
          ]
    
    ref_model_out = [
                    0x43e737d2, 0xc3ee0310,
                    0xc83b03dd, 0x46a80eba,
                    0x3f6e6360, 0xc05742d2,
                    0x4171871b, 0x4154ee6c, 0x7fc00000 
                    ]
   
    op  = ['+', '+', '*', '*', '/', '/', 'r', 'r', 'r']
    opcode  = [0b000, 0b000, 0b001, 0b001, 0b010, 0b010, 0b011, 0b011, 0b011]
    
    # Handshake
    await caravelEnv.wait_mgmt_gpio(1) # config ok
    
    # Operation
    hndshk = 0
    for i in range (len(op)):
        cocotb.log.info (f"\nOperation {hex(in1[i])} {op[i]} {hex(in2[i])} = {hex(ref_model_out[i])}")

        #In1
        caravelEnv.drive_gpio_in((32),0b0)
        caravelEnv.drive_gpio_in((37,35),0b010)
        caravelEnv.drive_gpio_in((31,0),in1[i])
        # Handshake
        await caravelEnv.wait_mgmt_gpio(hndshk)
        if hndshk==0: hndshk=1 
        else: hndshk=0
        #
        gpios_control = caravelEnv.monitor_gpio(37, 32).binstr
        gpios_switchable = hex(int(caravelEnv.monitor_gpio(31, 0).binstr,2))
        cocotb.log.info (f"Control:    IO[37:32] = 0b{gpios_control}")
        cocotb.log.info (f"In1:        IO[31:0]  = {gpios_switchable}")
        
        #In2
        caravelEnv.drive_gpio_in((37,35),0b110)
        caravelEnv.drive_gpio_in((31,0),in2[i])
        # Handshake
        await caravelEnv.wait_mgmt_gpio(hndshk)
        if hndshk==0: hndshk=1 
        else: hndshk=0
        #
        gpios_control = caravelEnv.monitor_gpio(37, 32).binstr
        gpios_switchable = hex(int(caravelEnv.monitor_gpio(31, 0).binstr,2))
        cocotb.log.info (f"Control:    IO[37:32] = 0b{gpios_control}")
        cocotb.log.info (f"In2:        IO[31:0]  = {gpios_switchable}")

        #Control
        caravelEnv.drive_gpio_in((37,35),0b100)
        caravelEnv.drive_gpio_in((31,29),opcode[i])
        caravelEnv.drive_gpio_in((27,25),0b001) #round mode
        caravelEnv.drive_gpio_in((32),0b1)
        # Handshake
        await caravelEnv.wait_mgmt_gpio(hndshk)
        if hndshk==0: hndshk=1 
        else: hndshk=0
         #
        gpios_control = caravelEnv.monitor_gpio(37, 32).binstr
        gpios_switchable = hex(int(caravelEnv.monitor_gpio(31, 0).binstr,2))
        cocotb.log.info (f"Control:    IO[37:32] = 0b{gpios_control}")
        cocotb.log.info (f"fpu ctr:    IO[31:0]  = {gpios_switchable}")

        #Out
        caravelEnv.drive_gpio_in((37,35),0b101)
        caravelEnv.release_gpio((31,0))
          
        # Handshake
        await caravelEnv.wait_mgmt_gpio(hndshk)
        if hndshk==0: hndshk=1 
        else: hndshk=0

        # Monitor & Checker
        gpios_control = caravelEnv.monitor_gpio(37, 32).binstr
        cocotb.log.info (f"Control:    IO[37:32] = 0b{gpios_control}")
        # gpios_switchable = hex(int(caravelEnv.monitor_gpio(31, 0).binstr,2)) #caravelEnv.monitor_gpio(31, 0).binstr
        gpios_switchable = hex(int(caravelEnv.monitor_gpio(31, 0).binstr,2))
        if (gpios_switchable == hex(ref_model_out[i])):  
          cocotb.log.info (f"[TEST PASS] IO[31:0]  = {gpios_switchable}")
        else:
          cocotb.log.error (f"[TEST FAIL] IO[31:0]  = {gpios_switchable}     expected = {hex(ref_model_out[i])}")        

        # Handshake
        await caravelEnv.wait_mgmt_gpio(hndshk)
        if hndshk==0: hndshk=1 
        else: hndshk=0

                #
        # gpios_switchable = hex(int(caravelEnv.monitor_gpio(31, 0).binstr,2)) #caravelEnv.monitor_gpio(31, 0).binstr
        # cocotb.log.info (f"[DEBUG] IO[31:0]  = {gpios_switchable}")
        
        
    await caravelEnv.wait_mgmt_gpio(hndshk)

    cocotb.log.info (f"[TEST PASSED] ")
