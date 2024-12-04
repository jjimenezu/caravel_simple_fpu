// SPDX-FileCopyrightText: 2024 jjimenezu
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0


#include <firmware_apis.h> // include required APIs

//############# FPU Firmware ##############################



unsigned fpu_op (char op, unsigned int in1, unsigned int in2){
    if (op=='+'){
        LogicAnalyzer_write(2,0x100);
    } else if (op=='*'){
        LogicAnalyzer_write(2,0x110);
    } else if (op=='/'){
        LogicAnalyzer_write(2,0x120);
    } else if (op=='r'){
        LogicAnalyzer_write(2,0x130);
    } else if (op=='c'){
        LogicAnalyzer_write(2,0x140);
    }

    LogicAnalyzer_write(0, in1);
    LogicAnalyzer_write(1, in2);

    if        (op=='+'){
        LogicAnalyzer_write(2,0x101);
    } else if (op=='*'){
        LogicAnalyzer_write(2,0x111);
    } else if (op=='/'){
        LogicAnalyzer_write(2,0x121);
    } else if (op=='r'){
        LogicAnalyzer_write(2,0x131);
    } else if (op=='c'){
        LogicAnalyzer_write(2,0x141);
    }

    // revisar 'done'
    unsigned int la3 = LogicAnalyzer_read(3);
    return la3;

}


unsigned int fpu_ADD (int in1, int in2){   // todo: add round select input
    LogicAnalyzer_write(2,0x100);
    LogicAnalyzer_write(0, in1);
    LogicAnalyzer_write(1, in2);
    LogicAnalyzer_write(2,0x101);
    // revisar 'done'
    GPIOs_waitHigh(0b000001);
    unsigned int la3 = LogicAnalyzer_read(3);
    return la3;
}

unsigned int fpu_MUL (int in1, int in2){
    LogicAnalyzer_write(2,0x110);
    LogicAnalyzer_write(0, in1);
    LogicAnalyzer_write(1, in2);
    LogicAnalyzer_write(2,0x111);
    // revisar 'done'
    GPIOs_waitHigh(0b000001);
    unsigned int la3 = LogicAnalyzer_read(3);
    return la3;
}

unsigned int fpu_DIV (int in1, int in2){
    LogicAnalyzer_write(2,0x120);
    LogicAnalyzer_write(0, in1);
    LogicAnalyzer_write(1, in2);
    LogicAnalyzer_write(2,0x121);
   // revisar 'done'
    GPIOs_waitHigh(0b000001);
    unsigned int la3 = LogicAnalyzer_read(2);
    return la3;
}

unsigned int fpu_SQRT (int in1, int in2){
    LogicAnalyzer_write(2,0x130);
    LogicAnalyzer_write(0, in1);
    LogicAnalyzer_write(1, in2);
    LogicAnalyzer_write(2,0x131);
    // revisar 'done'
    GPIOs_waitHigh(0b000001);
    unsigned int la3 = LogicAnalyzer_read(3);
    return la3;
}

void fpu_COMP (int in1, int in2){
    LogicAnalyzer_write(2,0x140);
    LogicAnalyzer_write(0, in1);
    LogicAnalyzer_write(1, in2);
    LogicAnalyzer_write(2,0x141);
}

void config_FPU(){
    // IO config
    GPIOs_configureAll(GPIO_MODE_USER_STD_BIDIRECTIONAL);
    GPIOs_configure(31,GPIO_MODE_USER_STD_INPUT_PULLUP);
    GPIOs_configure(32,GPIO_MODE_USER_STD_INPUT_PULLDOWN);
    GPIOs_configure(33,GPIO_MODE_USER_STD_INPUT_PULLDOWN);
    GPIOs_configure(34,GPIO_MODE_USER_STD_INPUT_PULLDOWN);
    GPIOs_configure(35,GPIO_MODE_USER_STD_INPUT_PULLDOWN);
    GPIOs_configure(36,GPIO_MODE_USER_STD_INPUT_PULLDOWN);
    GPIOs_configure(37,GPIO_MODE_USER_STD_INPUT_PULLDOWN);
    GPIOs_loadConfigs(); // load the configuration
    // LA config
    LogicAnalyzer_outputEnable(0,0x00000000);        // 31       0
    LogicAnalyzer_outputEnable(1,0x00000000);        // 63      32
    LogicAnalyzer_outputEnable(2,0xFFF00000);        // 95      64  
    LogicAnalyzer_outputEnable(3,0xFFFFFFFF);        // 127     96
    // Reset sequence
    LogicAnalyzer_write(2,0x101);
    dummyDelay(1);
    LogicAnalyzer_write(2,0x000);
    dummyDelay(1);
    LogicAnalyzer_write(2,0x101);
    dummyDelay(1);
}
//#######################################################################



//########## MAIN
void main(){
   
   //
    ManagmentGpio_outputEnable();
    ManagmentGpio_write(0);
    enableHkSpi(0); // disable housekeeping spi

    config_FPU();
    dummyDelay(100);

    

    unsigned int in1[] = {
          0x43187d07, 0xc41ba642,
          0x43765d11, 0xc3010b01,
          0xc38dc2c6, 0xc441751b,
          0x4363dfa8, 0x43311bc1, 0xc3fb5d7a
    };

    unsigned int in2[] = {
          0x439af94e, 0x431292e9,
          0xc4425485, 0xc326b2ff,
          0xc3983be4, 0x436611ec,
          0x00000000, 0x00000000, 0x00000000
    };

    char op[]  = {'+', '+', '*', '*', '/', '/', 'r', 'r', 'r'};


    unsigned int out_dut;
     
    out_dut = fpu_op(op[0], in1[0], in2[0]);
    dummyDelay(100);
    ManagmentGpio_write(1);

    int hndshk = 0; //config ok
    for (int i=0; i<11,i+=1;){
        out_dut = fpu_op(op[i], in1[i], in2[i]);
        ManagmentGpio_write(hndshk);
        hndshk ^= 1;

        
    }



    // ejecutando modo In1
    dummyDelay(100000);

    ManagmentGpio_write(hndshk);


   return;
}
