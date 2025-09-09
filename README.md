# Azure Digital Twins - Overview 

Costa Rica

[![GitHub](https://badgen.net/badge/icon/github?icon=github&label)](https://github.com)
[![GitHub](https://img.shields.io/badge/--181717?logo=github&logoColor=ffffff)](https://github.com/)
[brown9804](https://github.com/brown9804)

Last updated: 2025-09-05

----------

> [!IMPORTANT]
> This guide walks you through setting up a digital twin of a warehouse using Azure Digital Twins and Digital Twin Definition Language (DTDL). It includes modeling, deployment, and integration steps.

<details>
<summary><b>List of References</b> (Click to expand)</summary>

- [What is Azure Digital Twins?](https://learn.microsoft.com/en-us/azure/digital-twins/overview)
- [Learn about twin models and how to define them in Azure Digital Twins](https://learn.microsoft.com/en-us/azure/digital-twins/concepts-models)
- [Azure Digital Twins pricing](https://azure.microsoft.com/en-us/pricing/details/digital-twins/)

</details>

> [!TIP]
> Using DTDL in Azure Digital Twins allows you to:
> - `Digitally represent` your warehouse `layout and operations`
> - `Monitor real-time data` from sensors and devices
> - `Simulate and optimize` workflows
> - `Build` scalable, intelligent `systems for logistics and automation`

## Prerequisites

> To enable and use DTDL with Azure Digital Twins:

- An `Azure subscription is required`. All other resources, including instructions for creating a Resource Group, are provided in this workshop.
- `Contributor role assigned or any custom role that allows`: access to manage all resources, and the ability to deploy resources within subscription.
- Azure Digital Twins instance ([pricing](https://azure.microsoft.com/en-us/pricing/details/digital-twins/)

  > This is the core service where your digital twin graph lives. `What it does?`
  > - Hosts your DTDL models.
  > - Stores twin instances (e.g., shelves, zones, robots).
  > - Stores twin instances (e.g., shelves, zones, robots).
  > - Enables querying and updating of twin states.

  <img width="886" height="1003" alt="image" src="https://github.com/user-attachments/assets/20fb97a3-cae6-43a9-ba2b-2160654276c7" />

- Azure IoT Hub: This service connects physical devices (e.g., sensors, robots) to Azure. `What it does?`
  - Receives telemetry from devices.
  - Sends commands to devices.
  - Acts as a bridge between the physical warehouse and its digital twin.
  - `How to setup?`: Normally, use IoT Hub routing to forward messages to Azure Functions or Event Grid.
    - Register each device with a unique ID.
    - Use device SDKs to send telemetry (e.g., temperature, load).
    - Secure with device authentication and access policies.
- Azure Functions or Event Grid: These services handle event-driven processing of telemetry and commands. `Use Functions to transform raw telemetry into meaningful updates for your twins.`
  - `Azure Functions:`
    - Serverless compute that reacts to IoT messages.
    - Updates twin properties or telemetry using SDKs.
    - Can be written in C#, Python, JavaScript, etc.
  - `Event Grid:`
    - Event routing service.
    - Connects IoT Hub to Digital Twins via event handlers.
    - Useful for scalable, loosely coupled architectures.
- Visual Studio Code with DTDL extension

    <img width="1914" height="1132" alt="image" src="https://github.com/user-attachments/assets/441ee1b2-af8e-44f8-b6d6-884ca6aea899" />

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) or SDK (Python, C#, etc.)

## What is DTDL?

> `DTDL (Digital Twin Definition Language)` is a JSON-based modeling language developed by Microsoft. It’s used to define the structure, behavior, and relationships of digital twins in Azure Digital Twins.

Think of DTDL as the **blueprint** for your digital twin system. It describes:
- **Entities** (e.g., shelves, robots, sensors)
- **Properties** (e.g., shelf capacity)
- **Telemetry** (e.g., temperature readings)
- **Commands** (e.g., move robot)
- **Relationships** (e.g., shelf belongs to zone)

> How DTDL is Used: 

1. **Modeling Components**: You create DTDL models for each warehouse component (shelf, zone, robot, etc.).
2. **Uploading Models**: These models are uploaded to your Azure Digital Twins instance.
3. **Instantiating Twins**: You create digital twin instances based on the models.
4. **Defining Relationships**: You connect twins to reflect real-world relationships (e.g., shelf is in zone).
5. **Streaming Data**: IoT devices send telemetry to Azure IoT Hub, which updates the twins.
6. **Visualizing and Interacting**: Use Azure Digital Twins Explorer or custom dashboards to monitor and control the system.

## Demo 

> [!NOTE]
> E.g Overall:
> - `DTDL models` define the structure of your warehouse components.
> - `Azure Digital Twins` hosts the models and twin instances.
> - `IoT Hub` connects real devices to the cloud.
> - `Functions/Event Grid` route data from devices to update the digital twins.

> Example of the deployment process for your warehouse digital twin using Azure Digital Twins and DTDL.

1. Create Azure Digital Twins Instance:
  - Go to [https://portal.azure.com](https://portal.azure.com/#home)
  - Search for **Azure Digital Twins** → Click **Create**

      <img width="1908" height="1011" alt="image" src="https://github.com/user-attachments/assets/21ae1100-12ec-408c-8e7a-e163bbfed95a" />

  - Choose a resource group, region, name, etc

      <img width="1382" height="998" alt="image" src="https://github.com/user-attachments/assets/4a617724-f1b5-4dae-9e90-0afee76988d7" />

  - Once deployed, note the **host URL** (e.g., `https://<your-instance>.api.<region>.digitaltwins.azure.net`)

      <img width="1892" height="990" alt="image" src="https://github.com/user-attachments/assets/919129d7-58dc-4272-bbc7-473b2033d006" />

2. Author DTDL Models in VS Code
 
  - Install Visual Studio or [Visual Studio Code](https://code.visualstudio.com/)
  - Add the [DTDL extension](https://marketplace.visualstudio.com/search?term=dtdl&target=VSCode&category=All%20categories&sortBy=Relevance) for syntax highlighting and validation

      <img width="1897" height="753" alt="image" src="https://github.com/user-attachments/assets/168d7145-1384-457a-b133-b9d7adb71142" />

  - Create a `.json` file for each model (e.g., `shelf.json`)
  - Use the DTDL schema to define properties, telemetry, and relationships

> For example: `Warehouse`: The top-level entity representing the entire facility. It contains multiple zones and has metadata like location.

<details>
<summary><b> Full Warehouse Model (`warehouse.json`)</b></summary>

```json
{
  "@id": "dtmi:warehouse:main;1",
  "@type": "Interface",
  "displayName": "Warehouse",
  "contents": [
    {
      "@type": "Property",
      "name": "location",
      "schema": "string"
    },
    {
      "@type": "Relationship",
      "name": "zones",
      "target": "dtmi:warehouse:zone;1"
    }
  ]
}
```

</details>




<details>
<summary><b> Zone Model (`zone.json`)</b></summary>

> **Zone**: A logical or physical section of the warehouse (e.g., receiving, storage, packing). It organizes shelves, sensors, and robots within a defined area.

```json
{
  "@id": "dtmi:warehouse:zone;1",
  "@type": "Interface",
  "displayName": "Zone",
  "contents": [
    {
      "@type": "Property",
      "name": "zoneType",
      "schema": "string"
    },
    {
      "@type": "Relationship",
      "name": "shelves",
      "target": "dtmi:warehouse:shelf;1"
    },
    {
      "@type": "Relationship",
      "name": "sensors",
      "target": "dtmi:warehouse:sensor;1"
    },
    {
      "@type": "Relationship",
      "name": "robots",
      "target": "dtmi:warehouse:robot;1"
    }
  ]
}
```

</details>

<details>
<summary><b> Shelf Model (`shelf.json`)</b></summary>

> **Shelf**: Represents a storage unit. It has a fixed capacity and reports its current load via telemetry. It belongs to a specific zone.

```json
{
  "@id": "dtmi:warehouse:shelf;1",
  "@type": "Interface",
  "displayName": "Shelf",
  "contents": [
    {
      "@type": "Property",
      "name": "capacity",
      "schema": "integer"
    },
    {
      "@type": "Telemetry",
      "name": "currentLoad",
      "schema": "integer"
    },
    {
      "@type": "Relationship",
      "name": "belongsToZone",
      "target": "dtmi:warehouse:zone;1"
    }
  ]
}
```

</details>

<details>
<summary><b> Sensor Model (`sensor.json`)</b></summary>

> **Sensor**: Monitors environmental conditions like temperature and humidity. Useful for compliance, safety, and operational efficiency.

```json
{
  "@id": "dtmi:warehouse:sensor;1",
  "@type": "Interface",
  "displayName": "Sensor",
  "contents": [
    {
      "@type": "Telemetry",
      "name": "temperature",
      "schema": "double"
    },
    {
      "@type": "Telemetry",
      "name": "humidity",
      "schema": "double"
    },
    {
      "@type": "Property",
      "name": "sensorType",
      "schema": "string"
    }
  ]
}
```

</details>


<details>
<summary><b> Robot Model (`robot.json`)</b></summary>

> **Robot**: Represents an autonomous machine like an AGV or robotic arm. It can report its battery level and receive commands to interact with shelves.

```json
{
  "@id": "dtmi:warehouse:robot;1",
  "@type": "Interface",
  "displayName": "Robot",
  "contents": [
    {
      "@type": "Property",
      "name": "robotId",
      "schema": "string"
    },
    {
      "@type": "Telemetry",
      "name": "batteryLevel",
      "schema": "double"
    },
    {
      "@type": "Command",
      "name": "moveToShelf",
      "request": {
        "name": "shelfId",
        "schema": "string"
      }
    }
  ]
}
```

</details>


<!-- START BADGE -->
<div align="center">
  <img src="https://img.shields.io/badge/Total%20views-1443-limegreen" alt="Total views">
  <p>Refresh Date: 2025-09-05</p>
</div>
<!-- END BADGE -->
