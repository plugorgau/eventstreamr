ko.bindingProvider.instance = new StringInterpolatingBindingProvider();

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
          viewModel.stations.remove(match) 
          viewModel.stations.push(ko.mapping.fromJS(data.content))
        }
      }
    });
  })




var removeStation = function(data, event) {
  $.ajax({
    url: "/api/station/"+ data.settings.macaddress(),
    type: 'DELETE'
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

