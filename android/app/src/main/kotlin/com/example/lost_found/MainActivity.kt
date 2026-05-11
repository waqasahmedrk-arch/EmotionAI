package com.example.lost_found

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.*

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.eeg/bluetooth"
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var socket: BluetoothSocket? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val deviceAddress = call.argument<String>("address")
                    val success = connectToDevice(deviceAddress)
                    result.success(success)
                }
                "disconnect" -> {
                    disconnectDevice()
                    result.success(true)
                }
            }
        }
    }

    private fun connectToDevice(address: String?): Boolean {
        if (address == null) return false
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        val device: BluetoothDevice = bluetoothAdapter!!.getRemoteDevice(address)
        val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // SPP UUID
        try {
            socket = device.createRfcommSocketToServiceRecord(uuid)
            socket!!.connect()
            return true
        } catch (e: IOException) {
            e.printStackTrace()
            return false
        }
    }

    private fun disconnectDevice() {
        try {
            socket?.close()
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }
}
