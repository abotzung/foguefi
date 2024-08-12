<?php
/**
 * Boot page for pxe/GRUB
 *
 * PHP version 5
 *
 * @category Boot
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @author   Alexandre Botzung <alexandre@botzung.fr>
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
/**
 * Boot page for pxe/GRUB
 *
 * @category Boot
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @author   Alexandre Botzung <alexandre@botzung.fr> 
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */

require '../../commons/base.inc.php';
header("Content-type: text/html"); // DANGER : !!!DOT NOT MODIFY THE HEADER!!! ; ELSE GRUB REFUSES TO "normal" THE WEBPAGE !!

if(isset($_REQUEST['testconn'])){ //A "dummy" routine for "testing connexion to FOG server..."
	// NOTE : GRUB (signed) cannot fetch files from a webserver in HTTPS mode.
    //        This piece of code try to deduce if SSL is enabled on FOG Server, and modify the grub variable "web" accordingly.
	echo "set httpproto=\"".FOGCore::$httpproto."\"\n";
	die("set testconn=1\n");
}


$items = array(
    'mac' => filter_input(INPUT_POST, 'mac'),
    'mac0' => filter_input(INPUT_POST, 'mac0'),
    'mac1' => filter_input(INPUT_POST, 'mac1'),
    'mac2' => filter_input(INPUT_POST, 'mac2')
);
$mac = FOGCore::fastmerge(
    explode('|', $items['mac']),
    explode('|', $items['mac0']),
    explode('|', $items['mac1']),
    explode('|', $items['mac2'])
);
$mac = implode(
    '|',
    array_values(
        array_unique(
            array_filter($mac)
        )
    )
);
FOGCore::getHostItem(
    false,
    false,
    true,
    false,
    false,
    $mac
);
new GrubBootMenu();
?>
