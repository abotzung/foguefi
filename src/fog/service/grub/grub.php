<?php

/**
 * Boot page for pxe/GRUB
 *
 * PHP version 5
 *
 * @category Boot
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @author   Alexandre Botzung <alexandre.botzung@grandest.fr>
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
/**
 * Boot page for pxe/GRUB
 *
 * @category Boot
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @author   Alexandre Botzung <alexandre.botzung@grandest.fr> 
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */

require '../../commons/base.inc.php';
header("Content-type: text/html"); // DANGER : !!!NE PAS CHANGER L'HEADER!!! ; SINON GRUB REFUSE DE "normal" LA PAGE !!

if($_REQUEST['testconn']){ // Un code bidon pour "tester la connexion..."
	// GRUB Ubuntu2.06 BUG + Proxmox 7.2 UEFI ; Aléatoirement, GRUB n'arrive pas à télécharger la page HTTP.
	// NOTE : Si (http,... n'est pas disponible, GRUB rebascule sur TFTP, en mode dégradée
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