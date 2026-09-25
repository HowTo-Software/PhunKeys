# PhunKeys

PhunKeys is a Project Zomboid Build 42 mod built to work with PhunMart vehicle shops.

It uses the real `Base.CarKey` and a custom **Vehicle Conversion Box** to turn vehicles into sellable trade-in keys that PhunMart can recognize and purchase.

It also adds a lightweight vehicle access-control system using the same real vehicle key.


## Vehicle Trade-Ins

Put the vehicle's real key inside the **Vehicle Conversion Box**.

Right-click the box and select:

**Transmute**

The vehicle is converted into a trade-in key that can be sold at the appropriate PhunMart shop for whatever price that vehicle has been configured for.

The resulting key is a trade-in item only.

It does **not** preserve:

* Vehicle condition
* Installed parts
* Fuel
* Inventory
* Armor
* Paint
* Damage
* ModData
* Claim data
* Ownership state
* Any other state from the original vehicle

The original vehicle is gone.

The trade-in key simply tells PhunMart:

> "This was this vehicle. Pay the configured trade-in value."

That's it.

## Lock / Grant Access

If the real vehicle key inside the Vehicle Conversion Box is **favorited**, PhunKeys switches from trade-in mode to vehicle access-control mode.

Instead of **Transmute**, the box will show either:

**Lock**

or:

**Grant Access**

depending on the current state of the vehicle.

### Lock

Selecting **Lock** protects the matching vehicle and revokes guest access.

The vehicle remains associated with its real vanilla key.

Players without the matching key are prevented from using protected vehicle mechanics and other guarded vehicle actions while guest access is disabled.

### Grant Access

Selecting **Grant Access** allows other players to interact with the protected vehicle without giving them the actual vehicle key.

Right-click the box again and the option changes back to:

**Lock**

So the access cycle is reversible:

```text
Favorited Key
     |
     v
    Lock
     |
     v
Guest Access Disabled
     |
     v
Grant Access
     |
     v
Guest Access Enabled
     |
     v
    Lock
```

Unfavorite the key and the box returns to **Transmute** mode.

## The Complete Cycle

The intended workflow is:

```text
Buy a vehicle key through PhunMart
        |
        v
Spawn the vehicle
        |
        v
Use the real vehicle key
        |
        +---- Unfavorited ----> Transmute ----> Sell trade-in key
        |
        +---- Favorited ------> Lock / Grant Access
```

The same real `Base.CarKey` drives both systems.


## Server Authority

PhunKeys validates vehicle operations server-side.

The server verifies the Vehicle Conversion Box, the contained real key, the key ID, the matching nearby vehicle, and the requested action.


## What PhunKeys Does Not Do

PhunKeys does not attempt to save and recreate complete vehicles.

It does not serialize vehicles.

It does not clone vehicle state.

It does not maintain a separate ownership database.

It does not replace vanilla vehicle keys.

It does not require ZombieBuddy.

The real vehicle and the real `Base.CarKey` remain the foundation of the system.


## PhunMart

PhunKeys provides the vehicle conversion and access-control side of the system.

Actual buy and sell prices are controlled through the PhunMart configuration.

Vehicle mods, shop pools, trade-in prices, and other economy content depend on the server's own PhunMart setup.

## Assets

Assets used by PhunKeys include:

* Vanilla `Base.CarKey`
* The custom **Lament Configuration / Vehicle Conversion Box** model
* A few externally sourced sound effects

The box exists as the physical interface between the player, their vehicle key, and the PhunKeys systems.


## In Extremely Simple Terms

Put key in box.

Right-click box.

If the key is not favorited:

**Transmute**

Sell the resulting key.

If the key is favorited:

**Lock**

or:

**Grant Access**

depending on what you last told the vehicle to do.

Who reads this anyway?
