Controller
==========

API
---


### Stations

Station related resources of *Eventstreamr controller API*.

#### Get Stations

* `GET /api/stations` will return all stations.

```json
[
  {
    "ip":"10.4.1.195",
    "settings":
      {
        "roles":[],
        "nickname":"",
        "macaddress":"00-21-5c-02-02-27",
        "room":""
      },
    "_id":"xZljygFs4qRG3jaQ"
  }
]
```

#### Get Station

* `GET /api/station/[MACADDRESS]` will return the specified station.

```json
{
  "ip":"10.4.1.195",
  "settings":
    {
      "roles":[],
      "nickname":"",
      "macaddress":"00-21-5c-02-02-27",
      "room":""
    },
  "_id":"xZljygFs4qRG3jaQ"
}
```

#### Create Station


* `POST /api/station` will create a new station from the parameters passed

```json
{
  "macaddress": "00-B0-D0-86-BB-F7",
  "roles": [
    "controller"
  ],
  "room": "ROOM_ID",
  "nickname": "",
}
```
This will return `201 Created` along with the current JSON representation of the station if the creation was a success.

#### Register Station

* `PUT /api/station/[MACADDRESS]` will update a station with the parameters passed.

```json
{
  "status": "active"
}
```

This will return a `200 OK` if the update was a success along with the current JSON representation of the station.
    
    
#### Delete Station


* `DELETE /api/station/[MACADDRESS]`

This will return `204 No Content`
