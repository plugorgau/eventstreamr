ko.bindingProvider.instance = new StringInterpolatingBindingProvider();

var viewModel = {
  stations: ko.mapping.fromJS([])
}
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
        console.log(data)
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

