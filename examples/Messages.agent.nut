// MIT License
//
// Copyright 2018 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#require "AzureIoTHub.agent.lib.nut:5.0.0"

// - connects the device to Azure IoT Hub using the provided Device Connection String
// - enables cloud-to-device messages functionality
// - logs all messages received from the cloud
// - periodically (every 10 seconds) sends a message to the cloud. The message contains an integer value and the current
//   timestamp. The value increases by 1 with every sending, it restarts from 1 every time the example is restarted.


const SEND_MESSAGE_PERIOD = 10.0;

class MessagesExample {
    _counter = 0;
    _azureClient = null;
    _wakeupTimer = null;

    constructor(deviceConnStr) {
        _azureClient = AzureIoTHub.Client(deviceConnStr,
            _onConnected.bindenv(this), _onDisconnected.bindenv(this));
    }

    function start() {
        _azureClient.connect();
    }

    function sendMessage() {
        local msgBody = format("Counter=%i Timestamp=%i", _counter, time());
        local message = AzureIoTHub.Message(msgBody);
        _counter++;
        _azureClient.sendMessage(message, _onMessageSent.bindenv(this));
    }

    function _onMessageSent(err, msg) {
        if (err != 0) {
            server.error("AzureIoTHub sendMessage failed: " + err);
        } else {
            server.log("Message successfully sent: " + msg.getBody());
        }
        _wakeupTimer = imp.wakeup(SEND_MESSAGE_PERIOD, function () {
            sendMessage();
        }.bindenv(this), "sendMessage");
    }

    function _onConnected(err) {
        if (err != 0) {
            server.error("AzureIoTHub connect failed: " + err);
            return;
        }
        server.log("Connected!");
        _azureClient.enableIncomingMessages(_onMessage.bindenv(this), function (err) {
            if (err != 0) {
                server.error("AzureIoTHub enableIncomingMessages failed: " + err);
            }
        });
        sendMessage();
    }

    function _onDisconnected(err) {
        server.log("Disconnected!");
        if (_wakeupTimer) imp.cancelwakeup(_wakeupTimer);
        server.log("Reconnecting...");
        _azureClient.connect();
    }

    function _onMessage(msg) {
        server.log("Message received:");
        server.log("body: " + msg.getBody());
        if (msg.getProperties() != null) {
            server.log("properties:");
            _printTable(msg.getProperties());
        }
    }

    function _printTable(tbl) {
        foreach (k, v in tbl) {
            server.log(k + " : " + v);
        }
    }
}

// RUNTIME
// ---------------------------------------------------------------------------------

// AzureIoTHub constants
// ---------------------------------------------------------------------------------
const AZURE_DEVICE_CONN_STRING = "<YOUR_AZURE_DEVICE_CONN_STRING>";

// Start application
messagesExample <- MessagesExample(AZURE_DEVICE_CONN_STRING);
messagesExample.start();
