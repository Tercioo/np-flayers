$(function () {
    //add function
    function onPlaceFlayerButtonPress() {
        var url = $("#url").val();
        var expirationTime;
        var radioBoxes = getRadionBoxes();
        if (radioBoxes[0].checked) {
            expirationTime = 28800;
        }
        else if (radioBoxes[1].checked) {
            expirationTime = 86400;
        }
        else if (radioBoxes[2].checked) {
            expirationTime = 259200;
        }
        $.post("http://np-flayers/addnewflayer", JSON.stringify({
            url: url,
            expirationTime: expirationTime
        }));
    }
    var placeFlayerButton = document.getElementById("placeflayer");
    placeFlayerButton.addEventListener("click", onPlaceFlayerButtonPress);
    //cancel function
    function onCancelButtonPress() {
        $.post("http://np-flayers/cancelnewflayer");
    }
    var clickButton = document.getElementById("cancel");
    clickButton.addEventListener("click", onCancelButtonPress);
    //listeners
    window.addEventListener("message", function (event) {
        var data = event.data;
        //see what event has been passed from lua
        switch (data.type) {
            case "showcreatepanel":
                {
                    $("#url").text("");
                    var radioBoxes = getRadionBoxes();
                    radioBoxes[0].checked = true;
                    radioBoxes[1].checked = false;
                    radioBoxes[2].checked = false;
                    showPanel();
                    break;
                }
            case "hidecreatepanel":
                {
                    hidePanel();
                    break;
                }
        }
    });
    //return an array with all radio boxes in the panel
    function getRadionBoxes() {
        var radioBox1 = $('#time1')[0];
        var radioBox2 = $('#time2')[0];
        var radioBox3 = $('#time3')[0];
        return new Array(radioBox1, radioBox2, radioBox3);
    }
    //show and hide functions
    function showPanel() {
        $("#flayerpanel").show();
    }
    function hidePanel() {
        $("#flayerpanel").hide();
    }
    //prints a value into the console
    function _debug(msg1) {
        this.console.log(msg1);
    }
    //panel initiates hidden
    hidePanel();
});
