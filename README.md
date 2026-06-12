# FPGA SSD1306 OLED Controller

This project provides FPGA code to interface an SSD1306-based OLED display from an FPGA platform. It is intended as a reusable open-source display module for FPGA-based embedded instrumentation projects.

## Overview

The design implements the control logic required to initialize and drive an SSD1306 OLED display. It provides the control logic for initialization, command transmission, and data writing to the OLED.

This code demonstrates the I2C protocol on C5G (Cyclone V GX Starter Kit). Changes may be needed to be used in a real project.

## Features

- SSD1306 OLED display initialization
- Display command transmission
- Data transmission to OLED
- FPGA-based hardware control
- Reusable module for embedded display applications

## Hardware

- OLED controller: SSD1306
- Display type: OLED module based on SSD1306
- FPGA platform: Cyclone V GX Starter Kit (C5G)
- Interface: I2C
  
## I2C Protocol

In I2C we have 2 pins:
- One clock output to the device (SCL).
- One data pin (SDA).

On the rising edge of the clock, data is latched in the device.  
After 8 data bits, the device sends an acknowledgement if everything is correct.

The usual sequence is:
1. Send device register address (SSD1306 I2C address)
2. Send address of the register where we want to write
3. Send data

### SSD1306 I2C Address

The SSD1306 OLED display uses I2C address **0x78** (binary: `01111000`). This is the device address written to the I2C bus before sending commands and data to the display. (Verify Address of the device).

## Reference Datasheet

This implementation is based on the SSD1306 controller datasheet:

- Solomon Systech SSD1306 datasheet: https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf

The command sequences, initialization flow, and interface behavior were derived from the manufacturer documentation.

## Repository Structure

- `rtl/` – FPGA HDL source files

## Pin Planner
<img width="937" height="102" alt="image" src="https://github.com/user-attachments/assets/d4144e60-8f21-4224-8100-ba16134b18e7" />


## Test Patterns

<img width="499" height="285" alt="1" src="https://github.com/user-attachments/assets/3ad48184-390e-461a-8a3a-c98fbfe1ac8f" />

<img width="458" height="240" alt="2" src="https://github.com/user-attachments/assets/93cb934e-c58d-4651-8ee7-ce2410386a12" />

<img width="498" height="373" alt="3" src="https://github.com/user-attachments/assets/e983d26d-0a59-4fc8-9be9-3fa2cac8bbe9" />
