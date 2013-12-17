Controller
==========

api

  Add Station
    Method
      POST
    Path
      /api/station
    Response
      Success
        code
          201

  Delete Station
    Method
      DELETE
    Path
      /api/station/[MACADDRESS]
    Response
      Success
        code
          204

  Get Station
    Method
      GET
    Path
      /api/station/[MACADDRESS]
    Response
      Success
        code
          200
        example
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

  Register Station
    Method
      POST
    Path
      /api/station/[MACADDRESS]
    Response
      New Station
        code
          201
      Success
        code
          200

  List Stations
    Method
      GET
    Path
      /api/stations
    Response
      Success
        code
          200
        example
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
    
    
    
    
    
    
    
    
    
    
    
    
    
    
