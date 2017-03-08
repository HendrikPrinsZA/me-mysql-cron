<?php
ini_set('display_errors', '1');

// $params = implode(";", $argv);
$params = array();
foreach ($argv as $arg) {
	$keyVal = explode("=", $arg);
	if (count($keyVal) > 1) {
		$params[$keyVal[0]] = $keyVal[1];
	}
}

$subject = "Cron Driver Notification (".date("Y-m-d H:i:s").")";

$msg = "";
$msg .= "Result: ";
if ($params['result'] === 'fail') {
	$msg .= "Failed :(";

	if (!empty($params['reason'])) { 
		$msg .= "\n".$params['reason'];
	}
	$msg .= "\n\n";
} else {
	$msg .= "Success :)";

	if (!empty($params['reason'])) { 
		$msg .= "\n".$params['reason'];
	}
	$msg .= "\n\n";
}

// Connection Details
$msg .= "=== Connection Details ===\n";
$msg .= "-host: ".$params['h']."\n";
$msg .= "-user: ".$params['u']."\n";
$msg .= "-database: ".$params['n']."\n";
// die($msg);

// send email
mail($params['to'], $subject, $msg);