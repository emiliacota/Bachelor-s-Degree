# 🌱 Smart Plant Monitor – Embedded Plant Monitoring System

Bachelor's Degree Project – "Gheorghe Asachi" Technical University of Iași, Faculty of Electronics, Telecommunications and Information Technology.

## 📋 About the project

Hybrid embedded system for monitoring indoor plants, combining sensor data acquisition with visual analysis of plant condition. The system tracks soil moisture, temperature, air humidity, and light intensity, and through a K-means segmentation algorithm applied to images, detects the health status of the leaf tissue (green/healthy, yellow/stressed, brown/dry).

## 🔧 System architecture

- **Perception layer:** ESP32 + DHT22 sensor (air temperature/humidity), capacitive soil moisture sensor, BH1750 sensor (light intensity)
- **Network layer:** Wi-Fi + MQTT protocol (Mosquitto broker)
- **Application layer:** Node-RED (interactive dashboard, decision algorithm, virtual assistant)
- **Visual analysis:** MATLAB script – K-means segmentation in RGB/HSV color space, sent to Node-RED via HTTP POST

## 🧰 Technologies used

- ESP32 (Arduino IDE / C++)
- MQTT (Mosquitto Broker)
- Node-RED + Node-RED Dashboard
- MATLAB (image processing, K-means algorithm)
- HTTP / JSON

## 📁 Repository structure

```
├── firmware/           # Arduino code for ESP32
├── matlab/              # K-means visual analysis script
├── node-red/             # Node-RED flow (JSON export) + custom widgets
├── docs/                # Thesis document (PDF) and presentation (PPTX)
├── images/               # Setup photos, wiring diagram, dashboard screenshots
└── README.md
```

## 🚀 Results

- Soil moisture: 45.9% | Temperature: 27.3 °C | Air humidity: 70.9%
- Visual analysis: 87.1% healthy green tissue, 6.3% yellow, 6.5% brown → status "Healthy"

## 📜 License

This project was developed for academic purposes, as part of a bachelor's degree thesis.
