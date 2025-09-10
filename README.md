# Azure Digital Twins - Overview 

Costa Rica

[![GitHub](https://badgen.net/badge/icon/github?icon=github&label)](https://github.com)
[![GitHub](https://img.shields.io/badge/--181717?logo=github&logoColor=ffffff)](https://github.com/)
[brown9804](https://github.com/brown9804)

Last updated: 2025-09-09

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


## Prerequisites

> To enable and use DTDL with Azure Digital Twins:

- An `Azure subscription is required`. All other resources, including instructions for creating a Resource Group, are provided in this workshop.
- `Contributor role assigned or any custom role that allows`: access to manage all resources, and the ability to deploy resources within subscription.
- Azure Digital Twins instance ([pricing](https://azure.microsoft.com/en-us/pricing/details/digital-twins/))

  > This is the core service where your digital twin graph lives. `What it does?`
  > - Hosts your DTDL models.
  > - Stores twin instances (e.g., shelves, zones, robots).
  > - Stores twin instances (e.g., shelves, zones, robots).
  > - Enables querying and updating of twin states.

  <img width="450" alt="image" src="https://github.com/user-attachments/assets/20fb97a3-cae6-43a9-ba2b-2160654276c7" />

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

    <img width="450" alt="image" src="https://github.com/user-attachments/assets/441ee1b2-af8e-44f8-b6d6-884ca6aea899" />

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) or SDK (Python, C#, etc.)

<!-- START BADGE -->
<div align="center">
  <img src="https://img.shields.io/badge/Total%20views-1391-limegreen" alt="Total views">
  <p>Refresh Date: 2025-09-10</p>
</div>
<!-- END BADGE -->
