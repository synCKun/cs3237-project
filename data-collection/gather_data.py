# -*- coding: utf-8 -*-
"""
TI CC2650 SensorTag
-------------------

Adapted by Ashwin from the following sources:
 - https://github.com/IanHarvey/bluepy/blob/a7f5db1a31dba50f77454e036b5ee05c3b7e2d6e/bluepy/sensortag.py
 - https://github.com/hbldh/bleak/blob/develop/examples/sensortag.py

"""
import asyncio
import platform
import struct
import datetime

from bleak import BleakClient

global_temp = None
global_light = None
global_humidity = None
global_pressure = None

def print_data():
    print(f'{global_temp}, {global_light}, {global_humidity}, {global_pressure}')

class Service:
    """
    Here is a good documentation about the concepts in ble;
    https://learn.adafruit.com/introduction-to-bluetooth-low-energy/gatt

    In TI SensorTag there is a control characteristic and a data characteristic which define a service or sensor
    like the Light Sensor, Humidity Sensor etc

    Please take a look at the official TI user guide as well at
    https://processors.wiki.ti.com/index.php/CC2650_SensorTag_User's_Guide
    """

    def __init__(self):
        self.data_uuid = None
        self.ctrl_uuid = None


class Sensor(Service):

    def callback(self, sender: int, data: bytearray):
        raise NotImplementedError()

    async def start_listener(self, client, *args):
        # start the sensor on the device
        write_value = bytearray([0x01])
        await client.write_gatt_char(self.ctrl_uuid, write_value)

        # listen using the handler
        await client.start_notify(self.data_uuid, self.callback)


class OpticalSensor(Sensor):
    def __init__(self):
        super().__init__()
        self.data_uuid = "f000aa71-0451-4000-b000-000000000000"
        self.ctrl_uuid = "f000aa72-0451-4000-b000-000000000000"

    def callback(self, sender: int, data: bytearray):
        raw = struct.unpack('<h', data)[0]
        m = raw & 0xFFF
        e = (raw & 0xF000) >> 12
        print((0.01 * (m << e)))
        global_light = 0.01 * (m << e)


class HumiditySensor(Sensor):
    def __init__(self):
        super().__init__()
        self.data_uuid = "f000aa21-0451-4000-b000-000000000000"
        self.ctrl_uuid = "f000aa22-0451-4000-b000-000000000000"

    def callback(self, sender: int, data: bytearray):
        (rawT, rawH) = struct.unpack('<HH', data)
        temp = -40.0 + 165.0 * (rawT / 65536.0)
        RH = 100.0 * (rawH/65536.0)
        global_temp = temp
        global_humidity = RH


class BarometerSensor(Sensor):
    def __init__(self):
        super().__init__()
        self.data_uuid = "f000aa41-0451-4000-b000-000000000000"
        self.ctrl_uuid = "f000aa42-0451-4000-b000-000000000000"

    def callback(self, sender: int, data: bytearray):
        (tL, tM, tH, pL, pM, pH) = struct.unpack('<BBBBBB', data)
        temp = (tH*65536 + tM*256 + tL) / 100.0
        press = (pH*65536 + pM*256 + pL) / 100.0
        global_temp = temp
        global_pressure = press


class LEDAndBuzzer(Service):
    """
        Adapted from various sources. Src: https://evothings.com/forum/viewtopic.php?t=1514 and the original TI spec
        from https://processors.wiki.ti.com/index.php/CC2650_SensorTag_User's_Guide#Activating_IO

        Codes:
            1 = red
            2 = green
            3 = red + green
            4 = buzzer
            5 = red + buzzer
            6 = green + buzzer
            7 = all
    """

    def __init__(self):
        super().__init__()
        self.data_uuid = "f000aa65-0451-4000-b000-000000000000"
        self.ctrl_uuid = "f000aa66-0451-4000-b000-000000000000"

    async def notify(self, client, code):
        # enable the config
        write_value = bytearray([0x01])
        await client.write_gatt_char(self.ctrl_uuid, write_value)

        # turn on the red led as stated from the list above using 0x01
        write_value = bytearray([code])
        await client.write_gatt_char(self.data_uuid, write_value)


async def run(address):
    async with BleakClient(address) as client:
        print("Connecting to: SensorTag")
        x = await client.is_connected()
        print("Connected: {0}".format(x))

        led_and_buzzer = LEDAndBuzzer()

        light_sensor = OpticalSensor()
        await light_sensor.start_listener(client)

        humidity_sensor = HumiditySensor()
        await humidity_sensor.start_listener(client)

        barometer_sensor = BarometerSensor()
        await barometer_sensor.start_listener(client)

        cntr = 0

        while True:
            # we don't want to exit the "with" block initiating the client object as the connection is disconnected
            # unless the object is stored
            await asyncio.sleep(0.1)

            print(f'{datetime.datetime.now()}: Temp = {global_temp}, Light = {global_light}, Humidty = {global_humidity}, Pressure = {global_pressure}')

            cntr += 1
            if cntr == 1000:
                await led_and_buzzer.notify(client, 0x02)
                cntr = 0


if __name__ == "__main__":
    """
    To find the address, once your sensor tag is blinking the green led after pressing the button, run the discover.py
    file which was provided as an example from bleak to identify the sensor tag device
    """

    import os

    os.environ["PYTHONASYNCIODEBUG"] = str(1)
    address = (
        "54:6c:0e:b5:56:00"
        if platform.system() != "Darwin"
        else "C7F84C68-B240-42A5-BBC5-094516247DBE"
    )
    loop = asyncio.get_event_loop()
    loop.run_until_complete(run(address))
    loop.run_forever()
