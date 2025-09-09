# Azure Digital Twins - Overview 

Costa Rica

[![GitHub](https://badgen.net/badge/icon/github?icon=github&label)](https://github.com)
[![GitHub](https://img.shields.io/badge/--181717?logo=github&logoColor=ffffff)](https://github.com/)
[brown9804](https://github.com/brown9804)

Last updated: 2025-09-05

----------

> [!NOTE]
> E.g Overall:
> - `DTDL models` define the structure of your warehouse components.
> - `Azure Digital Twins` hosts the models and twin instances.
> - `IoT Hub` connects real devices to the cloud.
> - `Functions/Event Grid` route data from devices to update the digital twins.

> Example of the deployment process for your warehouse digital twin using Azure Digital Twins and DTDL.

## Step 1: Create Azure Digital Twins Instance:
  - Go to [https://portal.azure.com](https://portal.azure.com/#home)
  - Search for **Azure Digital Twins** → Click **Create**

      <img width="1908" height="1011" alt="image" src="https://github.com/user-attachments/assets/21ae1100-12ec-408c-8e7a-e163bbfed95a" />

  - Choose a resource group, region, name, etc

      <img width="1382" height="998" alt="image" src="https://github.com/user-attachments/assets/4a617724-f1b5-4dae-9e90-0afee76988d7" />

  - Once deployed, note the **host URL** (e.g., `https://<your-instance>.api.<region>.digitaltwins.azure.net`)

      <img width="1892" height="990" alt="image" src="https://github.com/user-attachments/assets/919129d7-58dc-4272-bbc7-473b2033d006" />

## Step 2: Author DTDL Models in VS Code
 
  - Install Visual Studio or [Visual Studio Code](https://code.visualstudio.com/)
  - Add the [DTDL extension](https://marketplace.visualstudio.com/search?term=dtdl&target=VSCode&category=All%20categories&sortBy=Relevance) for syntax highlighting and validation

      <img width="1897" height="753" alt="image" src="https://github.com/user-attachments/assets/168d7145-1384-457a-b133-b9d7adb71142" />

  - Create a `.json` file for each model (e.g., `shelf.json`)
  - Use the DTDL schema to define properties, telemetry, and relationships

> For example: `Warehouse`: The top-level entity representing the entire facility. It contains multiple zones and has metadata like location.

<details>
<summary><b> Full Warehouse Model (warehouse.json)</b></summary>

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
<summary><b> Zone Model (zone.json)</b></summary>

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
<summary><b> Shelf Model (shelf.json)</b></summary>

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
<summary><b> Sensor Model (sensor.json)</b></summary>

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
<summary><b> Robot Model (robot.json)</b></summary>

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

### Step 3: Upload Models Using Azure CLI

> Once you've created your DTDL models (e.g., shelf.json, zone.json, etc.), you need to register them with your Azure Digital Twins instance.

- [How to install the Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Get started with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/get-started-with-azure-cli?view=azure-cli-latest)


> Commands:
> - Authenticates your session
> - Adds the necessary CLI extension
> - Uploads your DTDL models to the Azure Digital Twins instance

> [!NOTE]
> Models must be uploaded in dependency order. For example, `warehouse.json` references `zone.json`, so `zone.json` must be uploaded first.

```bash
az login
az extension add --name azure-iot
az dt model create --dt-name <your-instance-name> --models shelf.json zone.json sensor.json robot.json warehouse.json
```

## Step 4: Instantiate Twins and Define Relationships

> After uploading models, you create **twin instances**—these are the actual digital representations of your physical components.

> [!TIP]
> Use meaningful twin IDs like `zone01`, `robotA`, `sensorTemp01` to keep your graph organized.

1. Create a Twin: 

> E.g This creates a twin named `shelf01` based on the `Shelf` model.

```bash
az dt twin create \
  --dt-name <your-instance-name> \
  --twin-id shelf01 \
  --model-id dtmi:warehouse:shelf;1
```


2. Define Relationships:

> E.g This links `shelf01` to `zone01` using the `shelves` relationship defined in your DTDL.


```bash
az dt twin relationship create \
  --dt-name <your-instance-name> \
  --twin-id zone01 \
  --relationship-id zone01_shelf01 \
  --target shelf01 \
  --relationship-name shelves
```

## Step 5: Connect IoT Devices via IoT Hub

> To bring your digital twin to life, you need **real-time data** from physical devices.

> [!TIP]
> Use device twins in IoT Hub to store metadata like location or calibration settings.

1. Create an **Azure IoT Hub** in the portal
2. Register each device (e.g., temperature sensor, robot)
3. Use device SDKs (Python, C#, Node.js) to send telemetry

> Example Telemetry Payload:

E.g This data will be routed to Azure Digital Twins to update the `currentLoad` telemetry of a shelf.

```json
{
  "currentLoad": 42
}
```



## Step 6: Route Telemetry Using Azure Functions

> Azure Functions act as **middleware** to process incoming telemetry and update your digital twins.

> [!TIP]
> Use batching and filtering to optimize performance for large-scale environments.

1. Create a Function App
2. Add a trigger for IoT Hub messages
3. Use Azure Digital Twins SDK to patch twin data

> Example Python Code:

E.g This updates the `currentLoad` property of `shelf01` in real time.

```python
client.update_digital_twin(
  twin_id="shelf01",
  patch=[{"op": "replace", "path": "/currentLoad", "value": 42}]
)
```

## Step 7: Visualize Using Digital Twins Explorer

> Azure Digital Twins Explorer is a **graphical interface** to view and interact with your twin graph.

1. Download the tool from https://learn.microsoft.com/en-us/azure/digital-twins/overview-digital-twins-explorer
2. Connect it to your Azure Digital Twins instance
3. Explore:
   - Twin relationships
   - Real-time telemetry
   - Model structure

> [!TIP]
> Use the query editor to run graph queries like:

```sql
SELECT * FROM digitaltwins WHERE IS_OF_MODEL('dtmi:warehouse:shelf;1')
```




<!-- START BADGE -->
<div align="center">
  <img src="https://img.shields.io/badge/Total%20views-1323-limegreen" alt="Total views">
  <p>Refresh Date: 2025-09-09</p>
</div>
<!-- END BADGE -->
