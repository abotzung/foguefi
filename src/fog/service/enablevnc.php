<?php
/**
 * Redirige les connexions VNC vers le dernier administrateur connecté sur l'interface web de FOG.
 * Nécessite socat pour rediriger les connexions.
 *
 * PHP version 5
 *
 * @category Boot
 * @package  FOGUefi
 * @author   Alexandre Botzung <alexandre.botzung@grandest.fr>
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
/**
 * Redirige les connexions VNC vers le dernier administrateur connecté sur l'interface web de FOG.
 * Nécessite socat pour rediriger les connexions.
 *
 * @category Boot
 * @package  FOGUefi
 * @author   Alexandre Botzung <alexandre.botzung@grandest.fr> 
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
//
// Dans le cas où ce comportement ne serait pas souhaitable, 
//   La ligne de code ci-dessous doit être décommenté : 
//
// exec("socat tcp4-connect:" . $_SERVER['REMOTE_ADDR'] . ":5901 tcp4-connect:321.321.321.321:5500" . " > /dev/null &"); die();
//
// Replacez l'adresse ip 321.321.321.321 par l'adresse IP de votre poste en écoute TightVNC, même chose pour le port.


error_reporting(0);
$config = parse_ini_file("/opt/fog/.fogsettings");

$SQLuser=$config['snmysqluser'];
$SQLpass=$config['snmysqlpass'];
$SQLserv=$config['snmysqlhost'];
try {
  $conn = new PDO("mysql:host=$SQLserv;dbname=fog", $SQLuser, $SQLpass);
  // set the PDO error mode to exception
  $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
  //echo "Connected successfully";
  $stmt = $conn->prepare("SELECT hIP FROM history ORDER BY 'hID' DESC LIMIT 1;");
  $stmt->execute();
  $result = $stmt->setFetchMode(PDO::FETCH_ASSOC);
  $ipary=$stmt->fetchAll()[0];
  //echo $ipary['hIP'];
  exec("socat tcp4-connect:" . $_SERVER['REMOTE_ADDR'] . ":5901 tcp4-connect:".$ipary['hIP'].":5500" . " > /dev/null &");
} catch(PDOException $e) {
  echo "Connection failed"; //: " . $e->getMessage();
}
?>
