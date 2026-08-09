# AssetPulse Pro - Database Architecture & Entity Schema

## Overview & Core Philosophy
The hierarchy must be flexible enough to support distinct structural requirements for different departments (Electrical, Mechanical, Instrumentation, Production/Operations).

To achieve this, the core rule of AssetPulse Pro is:
**A `MasterEquipment` MUST link directly to a `Location`. It MAY optionally link to a `Panel` and `Feeder` if it requires rigid electrical power or control.**

This "Functional Location" vs "Equipment" model (standard in SAP PM/IBM Maximo) prevents database fragmentation and ensures a single unified Checklist, Fault Logging, and Work Order engine works across the entire plant.

---

## Standard Audit Fields
To maintain strict traceability across all workflows, **every single entity** in the hierarchy (Locations, Panels, Feeders, Master Equipments, Assets) must carry the exact same standard operational data:
- `id`: Unique identifier (String)
- `name`: Human-readable name (String)
- `description`: Contextual details (String)
- `createdAt`: Record creation time (Timestamp)
- `createdBy`: User ID who created it (String)
- `modifiedAt`: Last edit time (Timestamp)
- `modifiedBy`: User ID who modified it (String)

---

## Entity Levels & Hierarchy

### Level 1: `locations` (Areas / Rooms)
A physical place in the plant. A single location (like a Panel Room) can house both electrical Panels and independent mechanical equipments.
- **Fields**: *[Standard Audit Fields]* + `unitId`, `plantId`, `businessId`
- **Types**: `area`, `room`, `substation`, `building`, `panel_room`, `office`, `store`

### Level 2 (Optional): `panels` (MCC / PCC / LDB / PLC Panels / Switchboards)
Power distribution or instrumentation panels. These exist *inside* a `Location`.
- **Fields**: *[Standard Audit Fields]* + `locationId` (Required)
- **Types**: `mcc`, `pcc`, `ldb`, `plc_panel`, `utility_board`

### Level 3 (Optional): `feeders` (Power / IO Sources)
The specific switch, breaker, or IO channel providing power/control from a `Panel`.
- **Fields**: *[Standard Audit Fields]* + `panelId` (Required)
- **Types**: `motor_feeder`, `welding_outlet`, `power_outlet`, `vfd_feeder`, `io_channel`, `lighting_circuit`

### Level 4: `master_equipments` (Functional Equipments & Utility Bases)
The systemic function, assembly, or physical utility box.
- **Fields**: *[Standard Audit Fields]* + `unitId`, `businessId`, `plantId`
- **Relational Links**: 
  - `locationId` (**REQUIRED**: All master equipments physically exist somewhere)
  - `panelId` (**OPTIONAL**: Omitted for pure mechanical/operational assets)
  - `feederId` (**OPTIONAL**: Omitted for pure mechanical/operational assets)

### Level 5: `assets` (Individual Trackable Parts / Components)
The specific physical, serial-numbered component attached to a Master Equipment (e.g., The Motor, The Pump, The Breaker).
- **Fields**: *[Standard Audit Fields]* + Technical Specs + Health Status + Vibration + IR
- **Relational Links**: `masterEquipmentId` (Required)
- **Types**: `motor`, `pump`, `gearbox`, `panel`, `vfd`, `sensor`, `transmitter`, `other`, `amenity`, `tool`

---

## Structural Workflow Examples by Scenario

### Scenario 1. Electrical Department (Rigid Power Tracking)
*Strict path tracking power generation to consumption.*
- **Location**: `PCM & Tilter Panel Room`
- **Panel**: `Tilter MCC`
- **Feeder**: `Tilter Hydraulic Pump-1 Feeder`
- **Master Equipment**: `Tilter Hydraulic Pump-1`
- **Asset**: `Tilter Pump-1 Motor` (Type: Motor)
  - *Action*: You track vibration and winding resistance against the specific Motor Asset.

### Scenario 2. Mechanical Department (Direct Location Placement)
*Direct placement of equipment inside physical locations, bypassing electrical power layers.*
- **Location**: `PCM & Tilter Panel Room`
- **Master Equipment**: `Tilter Hydraulic Power Pack` (Optionally omit Panel/Feeder)
- **Asset**: `Tilter Hydraulic Pump-1` (Type: Pump)
- **Asset**: `Hydraulic Oil Tank` (Type: Generic)
  - *Action*: You log a leak (Fault) against the Oil Tank Asset.

### Scenario 3. Utility Distribution (LDBs & Welding Outlets)
*Utilities act as small power distribution hubs located dynamically across the plant.*
- **Location**: `BF1 Cast House` (The physical area where the outdoor box sits)
- **Panel (Optional Power Source)**: `MCC-1 (PCM Panel Room)` (Where its main power comes from)
- **Feeder (Optional Power Source)**: `MCC-1 Welding Feeder 5` (The circuit breaker feeding the box)
- **Master Equipment**: `W/O-2 (BF1 Cast House)` (Type: Utility Distribution)
- **Asset**: `RCCB 40A 30mA`
  - *Action*: You log your Monthly RCCB tripping checklist against this specific Asset.
- **Asset**: `3-Phase Socket 63A`
  - *Action*: If the socket burns out, you log a breakdown (Fault) against it.

### Scenario 4. Portable Tools & General Amenities
*Items like Hand Drills, Portable Welding Machines, Water Coolers that move around and plug into various W/Os.*
- **Location**: `Maintenance Store Room` (Or their current physical resting location)
- **Master Equipment**: `Welding Machine 400A (#WM-05)` (Type: Portable Equipment)
- **Asset**: *Optional sub-components, or leave blank if you just want to track the whole machine.*
  - *Action*: Since Portable Equipment is registered in the main database, you can perform preventative maintenance checklists (Calibration) directly on the Welding Machine, without breaking the database structure.

### Scenario 5. Instrumentation Department
*Tracking control signals and field devices.*
- **Location**: `Field Area 1`
- **Panel**: `Main PLC Panel`
- **Feeder**: `Analog IO Channel 5`
- **Master Equipment**: `Main Steam Line`
- **Asset**: `Pressure Transmitter`

### Scenario 6. Production / Operations
*Top-level operational systems.*
- **Location**: `Casting Machine Area`
- **Master Equipment**: `Pig Casting Machine`
- **Asset**: `Main Conveyor Belt` (Type: Generic / Operations)
