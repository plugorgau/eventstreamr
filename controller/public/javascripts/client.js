ko.bindingProvider.instance = new StringInterpolatingBindingProvider();

var availableRoles = [
  {value: 'ingest', text: 'ingest'},
  {value: 'mixer', text: 'mixer'},
  {value: 'record', text: 'record'},
  {value: 'stream', text: 'stream'}
]

var roleDisplay = function(value, sourceData) {
   var selectedRoles = "",
       checked = $.fn.editableutils.itemsByValue(value, sourceData);
       
   if(checked.length) {
     $.each(checked, function(i, v) { 
       selectedRoles += "<li><span class='label label-info'>" + $.fn.editableutils.escape(v.text) + "</span></li>";
     });
     $(this).html('<ul class="list-inline">' + selectedRoles + '</ul>');
   } else {
     $(this).empty(); 
   }
}

function onlyUnique(value, index, self) { 
    return self.indexOf(value) === index;
}

var viewModel = {
  stations: ko.mapping.fromJS([]),
}

var statusArray = function(options) {
  // makes interface easier to write if status is an array of objects, 
  // but easier for the manager to keep it internally as an object of objects
  // can later make this observable to prevent updating the full interface (push, match station, update just status)

  var statusArray = []
  for( var i in options.data.status ) {
    if (options.data.status.hasOwnProperty(i)){
      options.data.status[i].name = i;

        // this is a hack, fix the manager so that running is populated properly
        // done enough yak shaving for one conference...
        if (typeof options.data.status[i].running == 'undefined') {
          options.data.status[i].running = '0';
        }
        if (typeof options.data.status[i].type == 'undefined') {
          options.data.status[i].type = 'internal';
        }
        // end nasty hack

      statusArray.push(options.data.status[i]);
    }
  }

  return statusArray;
}

var availableDevices = function(options) {
  // can later make this observable to prevent updating the full interface (push, match station, update just devices)
  // return array based on options.data.devices with options.data.settings.devices removed
  
  // create array based on options.data.devices
  var devicesArray = []
  for( var i in options.data.devices ) {
    if (options.data.devices.hasOwnProperty(i)){
      devicesArray.push(options.data.devices[i]);
    }
  }
  
  if (options.data.settings.devices == "all") {
    return devicesArray
  }
  else {
    // filter devicesArray to remove matchs from options.data.settings.devices
    var configured;
    if (options.data.settings.devices) {
      configured = options.data.settings.devices
    }
    else {
      configured = []
    }
    var unselectedDevices = devicesArray.filter(function(element) {
      // loop through configured and look for matching id
      var match = true;
      for (var i in configured) {
        if (configured[i].id == element.id) {
          match = false
        }
      }
      return match
    })
    
    return unselectedDevices
  }
}

var mapping = {
  create: function(options) {
    var innerModel = ko.mapping.fromJS(options.data)

    // availableDevices
    if (options.data.devices) {
      try {
        innerModel.availableDevices = availableDevices(options)
      }
      catch(err) {
        console.log(err)
        console.log("station devices broken, update the station!")
      }
      finally {
        console.log("Available devices populated successfully!")
      }
    }
    
    // statusArray
    if (options.data.status) {
      innerModel.statusArray = statusArray(options)
      console.log(options.data.status)
    } else {
      innerModel.statusArray = [];
    }
    return innerModel;
  }
};


viewModel.roomDuplicates = ko.computed(function() {
  return viewModel.stations().map(function(item) {
    return (item.settings.room ? item.settings.room() : '')
  })
})

viewModel.rooms = ko.computed(function() {
  return viewModel.roomDuplicates().filter(onlyUnique)
})

ko.applyBindings(viewModel);

var socket = io.connect('//:5001')


$.get( "/api/stations", function( data ) {
})
  .done(function(data) {
    ko.mapping.fromJS(data, mapping, viewModel.stations)
    socket.on('change', function (data) {
      console.log(data);
      if (data.type == 'remove') {
        viewModel.stations.remove(function(item) { 
          return item._id() == data.content
        })
      }
      if (data.type == 'insert') {
        viewModel.stations.push(ko.mapping.fromJS(data.content, mapping))
      }
      if (data.type == 'update') {
        var match = ko.utils.arrayFirst(viewModel.stations(), function(item) {
          return data.content._id === item._id();
        });
        if (match) {
          ko.mapping.fromJS(data.content, mapping, match)
        }
      }
      if (data.type == 'notify') {
      }

    });
  })

var removeDevice = function (configuredDevices, macaddress, id) {

  console.log(macaddress, configuredDevices, id)

  $.ajax({
    url: "/api/stations/"+ macaddress + '/partial',
    type: 'POST',
    data: {
      key: 'settings.devices',
      value: configuredDevices
    }
  })
    .done(function(id) {
      console.log( "removed device ", id );
    })
}

var availableDeviceClick = function (item, configured, macaddress) {
  var value = ko.toJS(item);
  var devices = ko.toJS(configured) || [];
  if (devices == 'all') {
    devices = [];
  }
  devices.push(value);
  
  var post = {};
  post.key = "settings.devices";
  post.value = devices;
  
  $.ajax({
    url: '/api/stations/' + macaddress() + '/partial',
    type: 'POST',
    data: post 
  })
};

var actionStationManagers = function(roomId, action) {
  ko.utils.arrayForEach(viewModel.stations(), function(station) {
    if (station.settings.room() === roomId) {
      var post = new Object();
      post.station_macaddress = station.settings.macaddress();
      post.id = "Station";
      post.command_url = "manager";
      post.action = action;
      actionStationPost(post);
    }
  })
}

var actionStations = function(roomId, action) {
  ko.utils.arrayForEach(viewModel.stations(), function(station) {
    if (station.settings.room() === roomId) {
      var post = new Object();
      post.station_macaddress = station.settings.macaddress();
      post.id = "all";
      post.command_url = "command";
      post.action = action;
      actionStationPost(post);
    }
  })
}

var actionStationManager = function(macaddress, action) {
  var post = new Object();
  post.station_macaddress = macaddress;
  post.id = "Station";
  post.command_url = "manager";
  post.action = action;
  actionStationPost(post);
}

$("body").on("click", ".actionOnclick", function (e) {
  var post = new Object();
  post.station_macaddress = $(e.currentTarget).closest("[data-macaddress]").data('macaddress');
  post.id = $(e.currentTarget).data('id');
  post.command_url = "command";
  post.action = $(e.currentTarget).data('action');
  actionStationPost(post);
});

var actionDevice = function(macaddress, device, action) {
  var post = new Object();
  post.station_macaddress = macaddress;
  post.id = device;
  post.command_url = "command";
  post.action = action;
  actionStationPost(post);
}

var actionStationPost = function(post) {
  console.log(post)
  $.ajax({
    url: '/api/station/' + post.station_macaddress + '/action',
    type: 'POST',
    data: post 
  })
}

var removeStation = function(data, event) {
  $.ajax({
    url: "/api/station/"+ data.settings.macaddress(),
    type: 'DELETE'
  })
    .done(function(data) {
      console.log( "removed station", JSON.stringify(data) );
    })
}

var removeStationRoom = function(data, event) {
  $.ajax({
    url: "/api/stations/"+ data.settings.macaddress()  + '/partial',
    type: 'POST',
    data: {
      key: 'settings.room',
      value: ''
    }
  })
    .done(function(data) {
      console.log( "removed station", JSON.stringify(data) );
    })
}

function submitStation(data, event) {
  var $form = $(event.currentTarget).parents('#add-station');

  $.ajax({
    type: "POST",
    url: "/api/station",
    data: data,
  })
    .done(function() {
      $form.collapse('hide')
    })
}   

var macRewrite = function(macaddress) {
  if (!macaddress) { return false }
  return macaddress.replace(/-\s*/g, ":")
}
