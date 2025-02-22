$(document).ready(function () {

    // all custom jQuery will go here
    $("#firstbutton").click(function () {
        $.ajax({
            url: "http://a6e9b737faf594210909d3d9e6ab9f90-107544507.us-east-1.elb.amazonaws.com:8081", success: function (result) {
                $("#firstbutton").toggleClass("btn-primary:focus");
                }
        });
    });
    $("#secondbutton").click(function () {
        $.ajax({
            url: "http://a4dfd790233fc4b849354c2526641c73-2010068910.us-east-1.elb.amazonaws.com:8082/trace", success: function (result) {
                $("#secondbutton").toggleClass("btn-primary:focus");
            }
        });
    });    
});