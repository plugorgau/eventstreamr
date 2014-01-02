ko.bindingProvider.instance = new StringInterpolatingBindingProvider();

var availableRoles = [
  {value: 'ingest', text: 'ingest'},
  {value: 'mixer', text: 'mixer'},
  {value: 'record', text: 'record'},
  {value: 'stream', text: 'stream'}
]

var availableDevices = function(devices) {
  var dataArray = $.map(devices,function(v){
    return {"value":v.id, "text": v.name};
  });
  console.log(dataArray)
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

var deviceDisplay = function(value, sourceData) {
  var selectedRoles = "",
       checked = $.fn.editableutils.itemsByValue(value, sourceData);
       
  if(checked.length) {
    $.each(checked, function(i, v) { 
      selectedRoles += '<div class="col-sm-6">' +
        '<div class="panel panel-default">' +
          '<div class="panel-heading">' +
            '<div class="control-actions btn-group">' +
              '<a class="btn btn-success btn-xs"> Start </a><a class="btn btn-warning btn-xs"> Restart</a><a class="btn btn-danger btn-xs"> Stop</a>' +
            '</div>' +
          '</div>' +
          '<div class="panel-body">' +
            $.fn.editableutils.escape(v.text) +
          '</div>' +
        '</div>' +
      '</div>';
     });
     $(this).html('<small><div class="row">' + selectedRoles + '</div></small>');
   } else {
     $(this).html('<small><button class="btn btn-default btn-xs">Add Device</button>'); 
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
    });
  })

var actionDevicePost = function(data) {
  $.ajax({
    url: data.station_ip + '/command/' + data.action,
    type: 'POST',
    data: {
      id: data.device_id,
    }
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

