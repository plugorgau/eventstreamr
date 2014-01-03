ko.bindingProvider.instance = new StringInterpolatingBindingProvider();

var availableRoles = [
  {value: 'ingest', text: 'ingest'},
  {value: 'mixer', text: 'mixer'},
  {value: 'record', text: 'record'},
  {value: 'stream', text: 'stream'}
]

var availableDevices = function(devices,configured) {
  var dataArray = $.map(devices,function(v){
    var availableDevice = {};
    availableDevice.name = v.name;
    availableDevice.id = v.id;
    availableDevice.type = v.type;
    for(var i in configured()) {
      var id = configured()[i].id();
      var test = availableDevice.id();
      if (id == test) {
        return;
      }
    }
    return availableDevice;
  });
  return dataArray
}

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
    ko.mapping.fromJS(data, viewModel.stations)
    socket.on('change', function (data) {
      console.log(data);
      if (data.type == 'remove') {
        viewModel.stations.remove(function(item) { 
          return item._id() == data.content
        })
      }
      if (data.type == 'insert') {
        viewModel.stations.push(ko.mapping.fromJS(data.content))
      }
      if (data.type == 'update') {
        var match = ko.utils.arrayFirst(viewModel.stations(), function(item) {
          return data.content._id === item._id();
        });
        if (match) {
          viewModel.stations.splice(viewModel.stations.indexOf(match),1,ko.mapping.fromJS(data.content));
        }
      }
      if (data.type == 'notify') {
      }

    });
  })

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

var availableDeviceClick = function (checked, configured, macaddress) {
  var value = {};
  value.id = checked.id();
  value.type = checked.type();
  value.name = checked.name();
  configured.push(value);
  
  var post = {};
  post.key = "settings.devices";
  post.value = configured();
  
  $.ajax({
    url: '/api/stations/' + macaddress() + '/partial',
    type: 'POST',
    data: post 
  })
};

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

