'use strict';

/* Controllers */

var myCtrls = angular.module('myApp.controllers', []);

myCtrls.controller('status-list', ['$scope', '$http', '$timeout',
    function($scope, $http, $timeout) {
        $scope.getData = function() {
        $http.get('http://10.2.0.206:3000/status').success(function(data) {
            for ( var station in data ) {
                var station_details = data[station];
                station_details.icon = 'ok';
                station_details.colour = 'green';
                var not_ok = 0;
                for ( var proc in station_details.status ) {
                    //alert( "station: " + station + " -> proc: " + proc );
                    var proc_details = station_details.status[proc];
                    if ( proc_details.status == 'started' ) {
                        proc_details.icon = 'ok';
                        proc_details.colour = 'green';
                    }
                    else {
                        not_ok++;
                        proc_details.icon = 'remove';
                        proc_details.colour = 'red';
                    }
                    if ( proc_details.type == 'file' ) {
                        var new_id = proc.substring(proc.lastIndexOf("/")+1, proc.length);
                        station_details.status[new_id] = proc_details;
                        delete station_details.status[proc];
                    }
                }
                if ( not_ok > 0 ) {
                    station_details.icon = 'remove';
                    station_details.colour = 'red';
                }
            }
            $scope.status_list = data;
        });
        }

        $scope.refreshData = function() {
            console.log( "refreshing data" );
            $scope.getData();
            $timeout( $scope.refreshData, 5000 );
        }

        $scope.refreshData();
    }]);

myCtrls.controller('example', [function() { }]);
