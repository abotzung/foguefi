<?php
/**
 * Boot menu for the fog GRUB pxe system
 *
 * PHP Version 5 
 *
 * @category Bootmenu
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @author   Alexandre Botzung <alexandre.botzung@grandest.fr>
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
/**
 * Boot menu for the fog GRUB pxe system
 *
 * @category Bootmenu
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @author   Alexandre Botzung <alexandre.botzung@grandest.fr>
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
class GrubBootMenu extends FOGBase
{
    /**
     * The kernel string
     *
     * @var string
     */
    private $_kernel;
    /**
     * The init string
     *
     * @var string
     */
    private $_initrd;
    /**
     * The boot url string
     *
     * @var string
     */
    private $_booturl;
    /**
     * The mem disk string
     *
     * @var string
     */
    private $_memdisk;
    /**
     * The memtest string
     *
     * @var string
     */
    private $_memtest;
    /**
     * The web string
     *
     * @var string
     */
    private $_web;
    /**
     * The default choice
     *
     * @var string
     */
    private $_defaultChoice;
    /**
     * The boot exit type
     *
     * @var string
     */
    private $_bootexittype;
    /**
     * The log level string
     *
     * @var string
     */
    private $_loglevel;
    /**
     * The storage information string
     *
     * @var string
     */
    private $_storage;
    /**
     * The shutdown string
     *
     * @var string
     */
    private $_shutdown;
    /**
     * The path string
     *
     * @var string
     */
    private $_path;
    /**
     * The hidden menu storage
     *
     * @var bool
     */
    private $_hiddenmenu;
    /**
     * The timeout of the menu
     *
     * @var int
     */
    private $_timeout;
    /**
     * The key sequance storage
     *
     * @var string
     */
    private $_KS;
    /**
     * The selectable exit types
     *
     * @var array
     */
    private static $_exitTypes = array();
    /**
     * Initializes the boot menu class
     *
     * @return void
     */
    public function __construct()
    {
        parent::__construct();
		
		// Alex 20230821 : TODO : Add mutiarch support.
		// Should be feseable ; Ubuntu (shim and grub signed) is supported on : amd64 + arm64 (only!)
		//  A more "traditionnal" GRUB can be achieved via iPXE (TODO : supports others "esoteric" achitectures ?)
	
        /*$grubChain = 'chain -ar ${boot-url}/service/ipxe/grub.exe '
            . '--config-file="%s"';
        $sanboot = 'sanboot --no-describe --drive 0x80';
        $refind = sprintf(
            'imgfetch ${boot-url}/service/ipxe/refind.conf%s'
            . 'chain -ar ${boot-url}/service/ipxe/refind_x64.efi',
            "\n"
        );
		*/

        /*if (stripos($_REQUEST['arch'], 'i386') !== false) {
            //user i386 boot loaders instead
            $refind = sprintf(
                'imgfetch ${boot-url}/service/ipxe/refind.conf%s'
                . 'chain -ar ${boot-url}/service/ipxe/refind_ia32.efi',
                "\n"
            );
        }

        if (stripos($_REQUEST['arch'], 'arm') !== false) {
            //use arm boot loaders instead
            $refind = 'chain -ar ${boot-url}/service/ipxe/refind_aa64.efi';
        }
		*/
		
		
        /*$grub = array(
            'basic' => sprintf(
                $grubChain,
                'rootnoverify (hd0);chainloader +1'
            ),
            '1cd' => sprintf(
                $grubChain,
                'cdrom --init;map --hook;root (cd0);chainloader (cd0)"'
            ),
            '1fw' => sprintf(
                $grubChain,
                'find --set-root /BOOTMGR;chainloader /BOOTMGR"'
            )
        );*/
		
        /*self::$_exitTypes = array(
            'sanboot' => $sanboot,
            'grub' => $grub['basic'],
            'grub_first_hdd' => $grub['basic'],
            'grub_first_cdrom' => $grub['1cd'],
            'grub_first_found_windows' => $grub['1fw'],
            'refind_efi' => $refind,
            'exit' => 'exit',
        );*/
        list(
            $webserver,
            $curroot
        ) = self::getSubObjectIDs(
            'Service',
            array(
                'name' => array(
                    'FOG_WEB_HOST',
                    'FOG_WEB_ROOT',
                )
            ),
            'value',
            false,
            'AND',
            'name',
            false,
            ''
        );
        $curroot = trim($curroot, '/');
        $webroot = '/fog/';
        $this->_web = sprintf('%s://%s%s', '${FOG_httpproto}', $webserver, $webroot); // 'web=' variable for Kernel boot
        
        // Partie commentée car impossible de charger un fichier depuis TFTP si HTTP est dysfonctionnel.
        /*GRUB loader Script*/
        /*$Send['booturl'] = array(
            "set fog_ip=$webserver",
            sprintf('set fog_webroot=%s', basename($curroot)),
            'set boot_url="('
            . self::$httpproto
            . ',$fog_ip)/$fog_webroot"',
			'set bootpath=$boot_url/service/grub/tftp/',
        );
        $this->_parseMe($Send);*/
        if (self::$Host->isValid()) {
            if (!self::$Host->get('inventory')->get('sysuuid')) {
                self::$Host
                    ->get('inventory')
                    ->set('sysuuid', $_REQUEST['sysuuid'])
                    ->set('hostID', self::$Host->get('id'))
                    ->save();
            }
        }
        /*$host_field_test = 'biosexit';
        $global_field_test = 'FOG_BOOT_EXIT_TYPE';
        if ($_REQUEST['platform'] == 'efi') {
            $host_field_test = 'efiexit';
            $global_field_test = 'FOG_EFI_BOOT_EXIT_TYPE';
        }*/
        $StorageNodeID = @min(
            self::getSubObjectIDs(
                'StorageNode',
                array(
                    'isEnabled' => 1,
                    'isMaster' => 1,
                )
            )
        );
        $StorageNode = new StorageNode($StorageNodeID);
        $serviceNames = array(
            'FOG_EFI_BOOT_EXIT_TYPE',
            'FOG_KERNEL_ARGS',
            'FOG_KERNEL_DEBUG',
            'FOG_KERNEL_LOGLEVEL',
            'FOG_KERNEL_RAMDISK_SIZE',
            'FOG_KEYMAP',
            'FOG_KEY_SEQUENCE',
            'FOG_MEMTEST_KERNEL',
            'FOG_PXE_BOOT_IMAGE',
            'FOG_PXE_BOOT_IMAGE_32',
            'FOG_PXE_HIDDENMENU_TIMEOUT',
            'FOG_PXE_MENU_HIDDEN',
            'FOG_PXE_MENU_TIMEOUT',
            'FOG_TFTP_PXE_KERNEL',
            'FOG_TFTP_PXE_KERNEL_32',
        );
        list(
            $exit,
            $kernelArgs,
            $kernelDebug,
            $kernelLogLevel,
            $kernelRamDisk,
            $keymap,
            $keySequence,
            $memtest,
            $imagefile,
            $init_32,
            $hiddenTimeout,
            $hiddenmenu,
            $menuTimeout,
            $bzImage,
            $bzImage32
        ) = self::getSubObjectIDs(
            'Service',
            array(
                'name' => $serviceNames
            ),
            'value',
            false,
            'AND',
            'name',
            false,
            ''
        );
        $memdisk = 'memdisk';
        $loglevel = $kernelLogLevel;
        $ramsize = $kernelRamDisk;
        $timeout = (
            $hiddenmenu > 0 && !$_REQUEST['menuAccess'] ?
            $hiddenTimeout :
            $menuTimeout
        ) * 1000;
        $keySequence = (
            $hiddenmenu > 0 && !$_REQUEST['menuAccess'] ?
            $keySequence :
            ''
        );
        if (isset($_REQUEST['arch']) && $_REQUEST['arch'] != 'x86_64') {
            $bzImage = $bzImage32;
            $imagefile = $init_32;
        }
        $kernel = $bzImage;
        if (self::$Host->get('kernel')) {
            $bzImage = trim(
                self::$Host->get('kernel')
            );
        }
        if (self::$Host->get('init')) {
            $imagefile = trim(
                self::$Host->get('init')
            );
        }

		// Le kernel linux chargée par GRUB
		$GRUB_UEFIKernel="linux_kernel";
		// L'initrd chargée par GRUB
		$GRUB_UEFIinitrd="fog_uefi.cpio.xz";
		
		$bzImage = $GRUB_UEFIKernel;
		$imagefile = $GRUB_UEFIinitrd;
		
		
        $StorageGroup = $StorageNode->getStorageGroup();
        /*$exit = trim(
            (
                self::$Host->get($host_field_test) ?:
                self::getSetting($global_field_test)
            )
        );
		
		
        if (!$exit || !in_array($exit, array_keys(self::$_exitTypes))) {
            $exit = 'sanboot';
        }*/
        $initrd = $imagefile;
		
		// ===== Give the opportunity to a hook for managing the kernel startup parameters (only if the host is valid)
		// Alex 20230821 : TODO : Add FOGUEFI_ in the name of all hook event name to dodge collisions with existings plugins.
        if (self::$Host->isValid()) {
            self::$HookManager->processEvent(
                'FOGUEFI_BOOT_ITEM_NEW_SETTINGS',
                array(
                    'Host' => &self::$Host,
                    'StorageGroup' => &$StorageGroup,
                    'StorageNode' => &$StorageNode,
                    'webserver' => &$webserver,
                    'webroot' => &$webroot,
                    'memtest' => &$memtest,
                    'memdisk' => &$memdisk,
                    'bzImage' => &$bzImage,
                    'imagefile' => &$imagefile,
                    'initrd' => &$initrd,
                    'loglevel' => &$loglevel,
                    'ramsize' => &$ramsize,
                    'keymap' => &$keymap,
                    'timeout' => &$timeout,
                    'keySequence' => &$keySequence,
                )
            );
        }
        $kernel = $bzImage;
        $initrd = $imagefile;
        $this->_timeout = $timeout;
        $this->_hiddenmenu = ($hiddenmenu && !$_REQUEST['menuAccess']);
        $this->_bootexittype = 'none'; /* INUSED bootexittype */ //self::$_exitTypes[$exit];
        $this->_loglevel = "loglevel=$loglevel";
        $this->_KS = self::getClass('KeySequence', $keySequence) || 'us';
        $this->_booturl = self::$httpproto
            . "://{$webserver}/fog/service";
		// v v v inutilisée v v v 
        //$this->_memdisk = "kernel $memdisk initrd=$memtest";
        //$this->_memtest = "initrd $memtest";
		
		
        $StorageNodes = (array)self::getClass('StorageNodeManager')
            ->find(
                array(
                    'ip' => array(
                        $webserver,
                        self::resolveHostname($webserver)
                    )
                )
            );
        if (count($StorageNodes) < 1) {
            $StorageNodes = (array)self::getClass('StorageNodeManager')
                ->find();
            foreach ($StorageNodes as $StorageNode) {
                $hostname = self::resolveHostname($StorageNode->get('ip'));
                if ($hostname == $webserver
                    || $hostname == self::resolveHostname($webserver)
                ) {
                    break;
                }
                $StorageNode = new StorageNode(0);
            }
            if (!$StorageNode->isValid()) {
                $storageNodeIDs = (array)self::getSubObjectIDs(
                    'StorageNode',
                    array('isMaster' => 1)
                );
                if (count($storageNodeIDs) < 1) {
                    $storageNodeIDs = (array)self::getSubObjectIDs(
                        'StorageNode'
                    );
                }
                $StorageNode = new StorageNode(@min($storageNodeIDs));
            }
        } else {
            $StorageNode = current($StorageNodes);
        }
        if ($StorageNode->isValid()) {
            $this->_storage = sprintf(
                'storage=%s:/%s/ storageip=%s',
                trim($StorageNode->get('ip')),
                trim($StorageNode->get('path'), '/'),
                trim($StorageNode->get('ip'))
            );
        }

        if (self::$Host->isValid() && self::$Host->get('task')->isValid()) {
			$GetTasking = self::$Host->get('task');
			$TaskType = $GetTasking->getTaskType();
			$TASK_HumanNameType=$TaskType->get('name');
			$TASK_Icon=$TaskType->get('icon');
        }

		// Alex 20230821 ; TODO : Run some sanity checks to GRUB security (prevent anyone to editiong GRUB commandline)
		// Some ressources : https://help.ubuntu.com/community/Grub2/Passwords / https://superuser.com/questions/1405178/disable-grub-boot-menu-parameters-editing-while-booting
		// https://www.gnu.org/software/grub/manual/grub/html_node/Authentication-and-authorisation.html
        $this->_kernel = sprintf(
			'linux "${bootpath}%s" %s initrd=%s root=/dev/ram0 rw '
            . 'ramdisk_size=%s%sweb=%s consoleblank=0%s rootfstype=ext4%s%s '
            . '%s nvme_core.default_ps_max_latency_us=0 $grub_parameter $gfxgui', 
            $bzImage,
            $this->_loglevel,
            basename($initrd),
            $ramsize,
            strlen($keymap) ? sprintf(' keymap=%s ', $keymap) : ' ',
            $this->_web,
            $kernelDebug ? ' debug' : ' ',
            $kernelArgs ? sprintf(' %s', $kernelArgs) : '',
            (
                self::$Host->isValid() && self::$Host->get('kernelArgs') ?
                sprintf(' %s', self::$Host->get('kernelArgs')) :
                ''
            ),
            $this->_storage
        );
			$this->_initrd = "initrd \"\${bootpath}$imagefile\"";
        self::$HookManager
            ->processEvent('FOGUEFI_BOOT_MENU_ITEM');
        $PXEMenuID = @max(
            self::getSubObjectIDs(
                'PXEMenuOptions',
                array(
                    'default' => 1
                )
            )
        );
        $defaultMenu = new PXEMenuOptions($PXEMenuID);
        $menuname = (
            $defaultMenu->isValid() ?
            trim($defaultMenu->get('name')) :
            'fog.local'
        );
        unset($defaultMenu);
        self::_getDefaultMenu(
            $this->_timeout,
            $menuname,
            $this->_defaultChoice
        );
        $this->_ipxeLog();
        if (self::$Host->isValid() && self::$Host->get('task')->isValid()) {
			# PATCH : If a task is programmed, and this task ISNT Snapin related, executes the task. 
			if ( !self::$Host->get('task')->isSnapinTasking() ) {
				$this->getTasking();
				exit;
			}
        }
        self::$HookManager->processEvent(
            'FOGUEFI_ALTERNATE_BOOT_CHECKS'
        );
        
        // Try to properly autenticate / dispatch tasking ========================
        
        // No menu ? NO MENU/TASK/...!
        list($noMenu) = self::getSubObjectIDs(
            'Service',
            array(
                'name' => array(
                    'FOG_NO_MENU',
                )
            ),
            'value',
            false,
            'AND',
            'name',
            false,
            ''
        );
        if ($noMenu) {
            $this->noMenu();
        }
        list($advLogin, $noMenu) = self::getSubObjectIDs(
            'Service',
            array(
                'name' => array(
                    'FOG_ADVANCED_MENU_LOGIN',
                    'FOG_NO_MENU',
                )
            ),
            'value',
            false,
            'AND',
            'name',
            false,
            ''
        );
        if (isset($_REQUEST['username']) && isset($_REQUEST['password'])) {
            $tmpUser = self::attemptLogin(
                $_REQUEST['username'],
                $_REQUEST['password']
            );
            if ($tmpUser->isValid()) {
				self::$HookManager
					->processEvent('FOGUEFI_ALTERNATE_LOGIN_BOOT_MENU_PARAMS');
					
				if (isset($_REQUEST['delconf'])) {
                    $this->_delHost();
                } elseif (isset($_REQUEST['key'])) {
                    $this->keyset();
                } elseif (isset($_REQUEST['sessname'])) {
                    $this->sesscheck();
                } elseif (isset($_REQUEST['aprvconf'])) {
                    $this->_approveHost();
                } elseif (isset($_REQUEST['qihost'])) {
					$this->setTasking($_REQUEST['imageID']);
				} else {
					// No task ? Just a login then !
					echo '#!ok';
				}
            } else {
				// Login invalid ? (Dosent care about a tasking) THROW ERROR AND STOP
				echo '#!ERR_INVALID_LOGIN';
				exit;
			}
        } else {
			//if (!self::$Host->isValid()) { // Invalid host ? Show default menu.
			// # 20230703 : By default, show the menu in all cases. 
			//              Because special cases are beiging handled just up there.
			//             GetTasking() is handled line 459
			$this->printDefault();
			//} else {					   // Else parse a potential tasking
			//	$this->getTasking();
			//}
		}
		// =======================================================================
    }
    /**
     * Sets the default menu item
     *
     * @param int    $timeout the timeout interval
     * @param string $name    the name to default to
     * @param mixed  $default the default item to set
     *
     * @return void
     */
    private static function _getDefaultMenu($timeout, $name, &$default)
    {
        $default = sprintf(
            'choose --default %s --timeout %s target && goto ${target}',
            $name,
            $timeout
        );
    }
    /**
     * Log's the current ipxe request
     *
     * @return void
     */
    private function _ipxeLog()
    {
		// Alex 20230821 : Update _ipxeLog
		// ***TODO*** : Switch logs to a proper item.
        $findWhere = array(
            'file' => sprintf('%s', isset($_REQUEST['filename']) ? trim(basename($_REQUEST['filename'])) : ''),
            'product' => sprintf('%s', isset($_REQUEST['product']) ? trim($_REQUEST['product']) : ''),
            'manufacturer' => sprintf('%s', isset($_REQUEST['manufacturer']) ? trim($_REQUEST['manufacturer']) : ''),
            'mac' => (
                self::$Host->isValid() ?
                self::$Host->get('mac')->__toString() :
                ''
            ),
        );
        $id = self::getSubObjectIDs('iPXE', $findWhere);
        $id = (isset($id) && is_array($id) && count($id) > 0) ? max($id) : 0;
        self::getClass('iPXE', $id)
            ->set('product', $findWhere['product'])
            ->set('manufacturer', $findWhere['manufacturer'])
            ->set('mac', $findWhere['mac'])
            ->set('success', 1)
            ->set('failure', 0)
            ->set('file', $findWhere['file'])
            ->set('version', isset($_REQUEST['ipxever']) ? trim($_REQUEST['ipxever']) : '')
            ->save();
    }
    /**
     * Deletes the current host
     *
     * @return void
     */
    private function _delHost()
    {
        if (self::$Host->destroy()) {
            $Send['delsuccess'] = array(
                'echo OKSUCCESS : Host deleted successfully',
                'sleep 3'
            );
        } else {
            $Send['delfail'] = array(
                'echo ERRFAILED : Failed to destroy Host!',
                'sleep 3',
            );
        }
        $this->_parseMe($Send);
    }
    /**
     * Print if this host is image ignored
     *
     * @return void
     */
    private function _printImageIgnored()
    {
        $Send['ignored'] = array(
            'echo The MAC Address is set to be ignored for imaging tasks',
            'sleep 15',
        );
        $this->_parseMe($Send);
        $this->printDefault();
    }
    /**
     * Approves a pending host
     *
     * @return void
     */
    private function _approveHost()
    {
        if (self::$Host->set('pending', null)->save()) {
            $Send['approvesuccess'] = array(
                'OKSUCCESS : Host approved successfully',
            );
            $shutdown = stripos(
                'shutdown=1',
                $_REQUEST['extraargs']
            );
            $isdebug = preg_match(
                '#isdebug=yes|mode=debug|mode=onlydebug#i',
                $_REQUEST['extraargs']
            );
            self::$Host->createImagePackage(
                10,
                'Inventory',
                $shutdown,
                $isdebug,
                false,
                false,
                $_REQUEST['username']
            );
        } else {
            $Send['approvefail'] = array(
                'FAILURE : Host approval failed',
            );
        }
        $this->_parseMe($Send);
    }
    /**
     * Prints the current tasking for the host
     *
     * @param array $kernelArgsArray the kernel args data
     *
     * @return void
     */
    private function _printTasking($kernelArgsArray)
    {
        $kernelArgs = array();
        foreach ((array)$kernelArgsArray as &$arg) {
            if (empty($arg)) {
                continue;
            }
            if (is_array($arg)) {
                if (!(isset($arg['value']) && $arg['value'])) {
                    continue;
                }
                if (!(isset($arg['active']) && $arg['active'])) {
                    continue;
                }
                $kernelArgs[] = preg_replace(
                    '#mode=debug|mode=onlydebug#i',
                    'isdebug=yes',
                    $arg['value']
                );
            } else {
                $kernelArgs[] = preg_replace(
                    '#mode=debug|mode=onlydebug#i',
                    'isdebug=yes',
                    $arg
                );
            }
            unset($arg);
        }
        $kernelArgs = array_filter($kernelArgs);
        $kernelArgs = array_unique($kernelArgs);
        $kernelArgs = array_values($kernelArgs);
        $kernelArgs = implode(' ', (array)$kernelArgs);
		
        if (self::$Host->isValid() && self::$Host->get('task')->isValid()) {
			$GetTaskType = self::$Host->get('task');
			$TaskType = $GetTaskType->getTaskType();
			//$KernelArgsFORTaskType = $TaskType->get('kernelArgs');
			$TASK_HumanNameType=$TaskType->get('name');
			$TASK_Icon=$TaskType->get('icon');
        }
		
        $Send['task'][(
            self::$Host->isValid() ?
            self::$Host->get('task')->get('typeID') :
            1
        )] = array( /* Mettre ICI l'arret d'urgence de la tâche */
			"set timeout=3 ; set default=0",
			"menuentry 'Scheduled tasking : ". $TASK_HumanNameType ."' --class ". $TASK_Icon ." --id scheduledtasking {",
			'echo "Loading kernel. . ."',
            "$this->_kernel $kernelArgs",
			'echo "Loading initrd. . ."',
            $this->_initrd,
			"}",
			'menuentry "Enable GUI" --class gear --id uefi-firmware {',
			'set gfxgui=gfxgui=xorg',
			'echo "Ok"',
			'}',
            '# bootmeifyoucan',
        );
        $this->_parseMe($Send);
    }
    /**
     * Checks that a session is valid and integrates the host to that
     * tasking.
     *
     * @return void
     */
    public function sesscheck()
    {
        $findWhere = array(
            'name' => trim($_REQUEST['sessname']),
            'stateID' => self::fastmerge(
                self::getQueuedStates(),
                (array)self::getProgressState()
            ),
        );
        foreach ((array)self::getClass('MulticastSessionManager')
            ->find($findWhere) as &$MulticastSession
        ) {
            if (!$MulticastSession->isValid()
                || $MulticastSession->get('sessclients') < 1
            ) {
                $MulticastSessionID = 0;
                unset($MulticastSession);
                continue;
            }
            $MulticastSessionID = $MulticastSession->get('id');
            unset($MulticastSession);
            break;
        }
        $MulticastSession = new MulticastSession($MulticastSessionID);
        if (!$MulticastSession->isValid()) {
            $Send['checksession'] = array(
                'ERRNOFOUND: No session found with that name.',
            );
            $this->_parseMe($Send);
            return;
        }
        $this->multijoin($MulticastSession->get('id'));
    }
    /**
     * False taskings are taskings for hosts that may not be
     * registered to the FOG Server.  This function allows actions
     * still occur
     *
     * @param mixed $mc    If the task is a multicast or not
     * @param mixed $Image The image to use for this false tasking
     *
     * @return void
     */
    public function falseTasking($mc = false, $Image = false)
    {
        $this->_kernel = str_replace(
            $this->_storage,
            '',
            $this->_kernel
        );
        $TaskType = new TaskType(1);
        if ($mc) {
            $Image = $mc->getImage();
            $TaskType = new TaskType(8);
        }
        $serviceNames = array(
            'FOG_DISABLE_CHKDSK',
            'FOG_KERNEL_ARGS',
            'FOG_KERNEL_DEBUG',
            'FOG_MULTICAST_RENDEZVOUS',
            'FOG_NONREG_DEVICE'
        );
        list(
            $chkdsk,
            $kargs,
            $kdebug,
            $mcastrdv,
            $nondev
        ) = self::getSubObjectIDs(
            'Service',
            array(
                'name' => $serviceNames
            ),
            'value',
            false,
            'AND',
            'name',
            false,
            ''
        );
        $shutdown = false !== stripos(
            'shutdown=1',
            $TaskType->get('kernelArgs')
        );
        if (!$shutdown && isset($_REQUEST['extraargs'])) {
            $shutdown = false !== stripos(
                'shutdown=1',
                $_REQUEST['extraargs']
            );
        }
        $StorageGroup = $Image->getStorageGroup();
        $StorageNode = $StorageGroup->getOptimalStorageNode();
        $osid = $Image->get('osID');
        $storage = escapeshellcmd(
            sprintf(
                '%s:/%s/%s',
                trim($StorageNode->get('ip')),
                trim($StorageNode->get('path'), '/'),
                ''
            )
        );
        $storageip = $StorageNode->get('ip');
        $img = escapeshellcmd($Image->get('path'));
        $imgFormat = (int)$Image->get('format');
        $imgType = $Image->getImageType()->get('type');
        $imgPartitionType = $Image->getPartitionType();
        $imgid = $Image->get('id');
        $chkdsk = $chkdsk == 1 ? 0 : 1;
        $ftp = $StorageNode->get('ip');
        $port = ($mc ? $mc->get('port') : null);
        $kernelArgsArray = array(
            "mac=$mac",
            "ftp=$ftp",
            "storage=$storage",
            "storageip=$storageip",
            "osid=$osid",
            "irqpoll",
            "chkdsk=$chkdsk",
            "img=$img",
            "imgType=$imgType",
            "imgPartitionType=$imgPartitionType",
            "imgid=$imgid",
            "imgFormat=$imgFormat",
            array(
                'value' => 'shutdown=1',
                'active' => $shutdown
            ),
            array(
                'value' => "mcastrdv=$mcastrdv",
                'active' => !empty($mcastrdv)
            ),
            array(
                'value' => "capone=1",
                'active' => !self::$Host || !self::$Host->isValid(),
            ),
            array(
                'value' => "port=$port mc=yes",
                'active' => $mc,
            ),
            array(
                'value' => 'debug',
                'active' => $kdebug,
            ),
            array(
                'value' => 'fdrive='.$nondev,
                'active' => $nondev,
            ),
            $TaskType->get('kernelArgs'),
            $kargs
        );
        $this->_printTasking($kernelArgsArray);
    }
    /**
     * Prints the image list for the ipxe menu
     *
     * @return void
     */
    public function printImageList()
    {
        $Send['ImageListing'] = array(
            '***!IMAGE-HEADER!***',
        );
        $defItem = '';
        /**
         * Sort a list.
         */
        $imgFind = array('isEnabled' => 1);
        if (!self::getSetting('FOG_IMAGE_LIST_MENU')) {
            if (!self::$Host->isValid()
                || !self::$Host->getImage()->isValid()
            ) {
                $imgFind = false;
            } else {
                $imgFind['id'] = self::$Host->getImage()->get('id');
            }
        }
        if ($imgFind === false) {
            $Images = false;
        } else {
            $Images = self::getClass('ImageManager')->find($imgFind);
        }
        if (!$Images) {
            $Send['NoImages'] = array(
                'ERROR : Host is not valid, host has no image assigned, or'
                . ' there are no images defined on the server.',
            );
            $this->_parseMe($Send);
        } else {
            array_map(
                function (&$Image) use (&$Send, &$defItem) {
                    if (!$Image->isValid()) {
                        return;
                    }
                    array_push(
                        $Send['ImageListing'],
                        sprintf(
                            'imgitem,%s,%s,%s',
                            escapeshellcmd($Image->get('path')),
                            $Image->get('name'),
                            $Image->get('id')
                        )
                    );
                    if (!self::$Host->isValid()) {
                        return;
                    }
                    if (!self::$Host->getImage()->isValid()) {
                        return;
                    }
                    if (self::$Host->getImage()->get('id') === $Image->get('id')) {
                        $defItem = sprintf(
                            'imgdefault,%s,%s,%s',
                            escapeshellcmd($Image->get('path')),
                            $Image->get('name'),
                            $Image->get('id')
                        );
                    }
                    unset($Image);
                },
                (array)$Images
            );
            array_push(
                $Send['ImageListing'],
                $defItem
            );
            $this->_parseMe($Send);
        }
    }
    /**
     * Joins the host with a session
     *
     * @param int $msid the session to join
     *
     * @return void
     */
    public function multijoin($msid)
    {
        $MultiSess = new MulticastSession($msid);
        if (!$MultiSess->isValid()) {
            return;
        }
        $msImage = $MultiSess->getImage()->get('id');
        if (self::$Host->isValid() && !self::$Host->get('pending')) {
            $h_Image = 0;
            $Image = self::$Host->getImage();
            if ($Image instanceof Image) {
                $h_Image = self::$Host->getImage()->get('id');
            }
            if ($msImage != $h_Image) {
                self::$Host
                    ->set('imagename', $MultiSess->getImage())
                    ->set('imageID', $msImage);
            }
        }
        $shutdown = stripos(
            'shutdown=1',
            $_REQUEST['extraargs']
        );
        $isdebug = preg_match(
            '#isdebug=yes|mode=debug|mode=onlydebug#i',
            $_REQUEST['extraargs']
        );
        if (self::$Host->isValid() && !self::$Host->get('pending')) {
            self::$Host->createImagePackage(
                8,
                $MultiSess->get('name'),
                $shutdown,
                $isdebug,
                -1,
                false,
                $_REQUEST['username'],
                '',
                true,
                true
            );
        } else {
            $this->falseTasking($MultiSess);
        }
    }
    /**
     * Set's the product key
     *
     * @return void
     */
    public function keyset()
    {
        if (!self::$Host->isValid()) {
            return;
        }
        self::$Host->set('productKey', $_REQUEST['key']);
        if (!self::$Host->save()) {
            $Send['keychangefailure'] = array(
                'ERROR : Unable to change key',
            );
        } else {
            $Send['keychangesuccess'] = array(
                'OKSUCCESS : Successfully changed key',
            );
        }
        $this->_parseMe($Send);
    }
    /**
     * Parses the information for us
     *
     * @param array $Send the data to parse
     *
     * @return void
     */
    private function _parseMe($Send)
    {
		/* Alex 20230821 : ***TODO***
		  GRUB "FOGUefi" *MUST* be separated from iPXE.
		  Also, some cleanup is required /!\
		*/
        self::$HookManager->processEvent(
            //'IPXE_EDIT',
			'FOGUEFI_EDIT',
            array(
                'ipxe' => &$Send,
                'Host' => &self::$Host,
                'kernel' => &$this->_kernel,
                'initrd' => &$this->_initrd,
                'booturl' => &$this->_booturl,
                'memdisk' => &$this->_memdisk,
                'memtest' => &$this->_memtest,
                'web' => &$this->_web,
                'defaultChoice' => &$this->_defaultChoice,
                'bootexittype' => &$this->_bootexittype,
                'storage' => &$this->_storage,
                'shutdown' => &$this->_shutdown,
                'path' => &$this->_path,
                'timeout' => &$this->_timeout,
                //'KS' => $this->ks // Key sequancing used by iPXE for accessing the menu, not used by GRUB
            )
        );
		// FIXED : Sometimes, $Send is not countable and crashes PHP8 (is_countable added)
		if (is_countable($Send) && count($Send) > 0) {
			array_walk_recursive(
				$Send,
				// FIXED : Argument #2 ($key) must be passed by reference (& removed from '$key' ; why ? )
				function (&$val, $key) {
					printf('%s%s', implode("\n", (array)$val), "\n");
					unset($val, $key);
				
				}
			);
		}
    }
    /**
     * Verifies credentials for us
     *
     * @return void
     */
    public function verifyCreds()
    {
        list($advLogin, $noMenu) = self::getSubObjectIDs(
            'Service',
            array(
                'name' => array(
                    'FOG_ADVANCED_MENU_LOGIN',
                    'FOG_NO_MENU',
                )
            ),
            'value',
            false,
            'AND',
            'name',
            false,
            ''
        );
        if ($noMenu) {
            $this->noMenu();
        }
        $tmpUser = self::attemptLogin(
            $_REQUEST['username'],
            $_REQUEST['password']
        );
        if ($tmpUser->isValid()) {
            self::$HookManager
                ->processEvent('FOGUEFI_ALTERNATE_LOGIN_BOOT_MENU_PARAMS');
            if ($_REQUEST['qihost']) {				/* Program image download (need mac, sysuuid, imageID)*/
                $this->setTasking($_REQUEST['imageID']);
            } else {
				// Une tentative de connexion, réussie mais sans tâche à exécuter ? 
				// Renvoie "#!ok"
				echo '#!ok';
                //$this->printDefault();
            }
        } else {
            $Send['invalidlogin'] = array(
                "#!ERR_INVALID_LOGIN",
            );
            $this->_parseMe($Send);
        }
    }
    /**
     * Sets a tasking element as needed
     *
     * @param mixed $imgID The image id to associate
     *
     * @return void
     */
    public function setTasking($imgID = '')
    {
        $shutdown = stripos(
            'shutdown=1',
            $_REQUEST['extraargs']
        );
        $isdebug = preg_match(
            '#isdebug=yes|mode=debug|mode=onlydebug#i',
            $_REQUEST['extraargs']
        );
        if (!$imgID) {
            $this->printImageList();
            return;
        }
        if (!self::$Host->isValid()) {
            $this->falseTasking('', self::getClass('Image', $imgID));
            return;
        }
        if (self::$Host->getImage()->get('id') != $imgID) {
            self::$Host
                ->set('imageID', $imgID)
                ->set('imagename', new Image($imgID));
        }
        if (!self::$Host->getImage()->isValid()) {
            return;
        }
        try {
            self::$Host->createImagePackage(
                1,
                'AutoRegTask',
                $shutdown,
                $isdebug,
                -1,
                false,
                $_REQUEST['username']
            );
            //$this->_chainBoot(false, true);
        } catch (Exception $e) {
            // TODO : Nettoyer tout ça ! 
            $Send['fail'] = array(
                '#!ipxe',
                sprintf('echo %s', $e->getMessage()),
                'sleep 3',
            );
            $this->_parseMe($Send);
        }
    }
    /**
     * No menu definition
     *
     * @return void
     */
    public function noMenu()
    {
        $Send['nomenu'] = array(
            'set timeout=3 ; set default=boothardisk',
            'menuentry "Boot from hard disk" --class drive-harddisk --id boothardisk {',
            'echo "Booting first local disk..."',
            '# Generate boot menu automatically',
            'configfile ${prefix}/boot-local-efi.cfg',
            '# If not chainloaded, definitely no uEFI boot loader was found.',
            'echo "No uEFI boot loader was found!"',
			'echo " => Restarting in 30 seconds"',
			'sleep 30',
			'reboot',
            '}',
        );
        $this->_parseMe($Send);
        exit;
    }
    /**
     * Get's a current tasking if any
     *
     * @return void
     */
    public function getTasking()
    {
        $Task = self::$Host->get('task');
        if (!$Task->isValid() || $Task->isSnapinTasking()) {
			// FOG is unable to handle multiples tasks for a single computer.
			// BUT, we can change the task in FOG/FOS by programming an other task.
			//
			// eg : a snapin tasking has been programmed.
			//      FOS can replace this task with a "download image" task instead. 
			
            //$this->printDefault();
            return 0;
        } else {
            if (self::$Host->get('mac')->isImageIgnored()) {
                $this->_printImageIgnored();
            }
            $this->_kernel = str_replace(
                $this->_storage,
                '',
                $this->_kernel
            );
            $TaskType = $Task->getTaskType();
            $imagingTasks = $TaskType->isImagingTask();
            if ($TaskType->isMulticast()) {
                $msaID = @max(
                    self::getSubObjectIDs(
                        'MulticastSessionAssociation',
                        array(
                            'taskID' => $Task->get('id')
                        )
                    )
                );
                $MulticastSessionAssoc = new MulticastSessionAssociation($msaID);
                $MulticastSession = $MulticastSessionAssoc->getMulticastSession();
                if ($MulticastSession && $MulticastSession->isValid()) {
                    self::$Host->set('imageID', $MulticastSession->get('image'));
                }
            }
            if ($TaskType->isInitNeededTasking()) {
                $Image = $Task->getImage();
                $StorageGroup = null;
                $StorageNode = null;
                self::$HookManager->processEvent(
                    'FOGUEFI_BOOT_TASK_NEW_SETTINGS',
                    array(
                        'Host' => &self::$Host,
                        'StorageNode' => &$StorageNode,
                        'StorageGroup' => &$StorageGroup,
                        'TaskType' => &$TaskType
                    )
                );
                if (!$StorageGroup || !$StorageGroup->isValid()) {
                    $StorageGroup = $Image->getStorageGroup();
                }
                $getter = 'getOptimalStorageNode';
                if ($Task->isCapture()
                    || $TaskType->isCapture()
                ) {
                    $StorageGroup = $Image->getPrimaryStorageGroup();
                    $getter = 'getMasterStorageNode';
                }
                if ($TaskType->isMulticast()) {
                    $getter = 'getMasterStorageNode';
                }
                if (!$StorageNode || !$StorageNode->isValid()) {
                    $StorageNode = $StorageGroup->{$getter}();
                }
                if ($Task->get('storagenodeID') != $StorageNode->get('id')) {
                    $Task->set('storagenodeID', $StorageNode->get('id'));
                }
                if ($Task->get('storagegroupID') != $StorageGroup->get('id')) {
                    $Task->set('storagegroupID', $StorageGroup->get('id'));
                }
                $Task->save();
                self::$HookManager->processEvent(
                    'FOGUEFI_BOOT_TASK_NEW_SETTINGS',
                    array(
                        'Host' => &self::$Host,
                        'StorageNode' => &$StorageNode,
                        'StorageGroup' => &$StorageGroup,
                        'TaskType' => &$TaskType
                    )
                );
                $osid = (int)$Image->get('osID');
                $storage = '';
                $img = '';
                $imgFormat = '';
                $imgType = '';
                $imgPartitionType = '';
                $serviceNames = array(
                    'FOG_CAPTUREIGNOREPAGEHIBER',
                    'FOG_CAPTURERESIZEPCT',
                    'FOG_CHANGE_HOSTNAME_EARLY',
                    'FOG_DISABLE_CHKDSK',
                    'FOG_KERNEL_ARGS',
                    'FOG_KERNEL_DEBUG',
                    'FOG_MULTICAST_RENDEZVOUS',
                    'FOG_PIGZ_COMP',
                    'FOG_TFTP_HOST',
                    'FOG_WIPE_TIMEOUT'
                );
                list(
                    $cappage,
                    $capresz,
                    $hosterl,
                    $chkdsk,
                    $kargs,
                    $kdebug,
                    $mcastrdv,
                    $pigz,
                    $tftp,
                    $timeout
                ) = self::getSubObjectIDs(
                    'Service',
                    array(
                        'name' => $serviceNames
                    ),
                    'value',
                    false,
                    'AND',
                    'name',
                    false,
                    ''
                );
                $shutdown = false !== stripos(
                    'shutdown=1',
                    $TaskType->get('kernelArgs')
                );
                if (!$shutdown && isset($_REQUEST['extraargs'])) {
                    $shutdown = false !== stripos(
                        'shutdown=1',
                        $_REQUEST['extraargs']
                    );
                }
                $globalPIGZ = $pigz;
                $PIGZ_COMP = $globalPIGZ;
                if ($StorageNode instanceof StorageNode && $StorageNode->isValid()) {
                    $ip = trim($StorageNode->get('ip'));
                    $ftp = $ip;
                }
                if ($imagingTasks) {
                    if (!($StorageNode instanceof StorageNode
                        && $StorageNode->isValid())
                    ) {
                        throw new Exception(_('No valid storage nodes found'));
                    }
                    $storage = escapeshellcmd(
                        sprintf(
                            '%s:/%s/%s',
                            $ip,
                            trim($StorageNode->get('path'), '/'),
                            (
                                $TaskType->isCapture() ?
                                'dev/' :
                                ''
                            )
                        )
                    );
                    $storageip = $ip;
                    $img = escapeshellcmd(
                        $Image->get('path')
                    );
                    $imgFormat = (int)$Image
                        ->get('format');
                    $imgType = $Image
                        ->getImageType()
                        ->get('type');
                    $imgPartitionType = $Image
                        ->getPartitionType();
                    $imgid = $Image
                        ->get('id');
                    $image_PIGZ = $Image->get('compress');
                    if (is_numeric($image_PIGZ) && $image_PIGZ > -1) {
                        $PIGZ_COMP = $image_PIGZ;
                    }
                    if (in_array($imgFormat, array('',null,0,1,2,3,4))) { // FIXME : PIGZ Level checked in iPXE, not in USB Boot method
                        if ($PIGZ_COMP > 9) {
                            $PIGZ_COMP = 9;
                        }
                    }
                } else {
                    // These setup so postinit scripts can operate.
                    if ($StorageNode instanceof StorageNode
                        && $StorageNode->isValid()
                    ) {
                        $ip = trim($StorageNode->get('ip'));
                        $ftp = $ip;
                    } else {
                        $ip = $tftp;
                        $ftp = $tftp;
                    }
                    $storage = escapeshellcmd(
                        sprintf(
                            '%s:/%s/dev/',
                            $ip,
                            trim($StorageNode->get('path'), '/')
                        )
                    );
                    $storageip = $ip;
                }
            }
            if (self::$Host->isValid()) {
                $mac = self::$Host->get('mac');
            } else {
                $mac = $_REQUEST['mac'];
            }
            $clamav = '';
            if (in_array($TaskType->get('id'), array(21, 22))) {
                $clamav = sprintf(
                    '%s:%s',
                    $ip,
                    '/opt/fog/clamav'
                );
            }
            $chkdsk = $chkdsk == 1 ? 0 : 1;
            $MACs = self::$Host->getMyMacs();
            $clientMacs = array_filter(
                (array)self::parseMacList(
                    implode(
                        '|',
                        (array)$MACs
                    ),
                    false,
                    true
                )
            );
			// PATCH - Disable ADparameters to be exposed inside boot events
            /*if (self::$Host->get('useAD')) {
                $addomain = preg_replace(
                    '#\s#',
                    '+_+',
                    self::$Host->get('ADDomain')
                );
                $adou = str_replace(
                    ';',
                    '',
                    preg_replace(
                        '#\s#',
                        '+_+',
                        self::$Host->get('ADOU')
                    )
                );
                $aduser = preg_replace(
                    '#\s#',
                    '+_+',
                    self::$Host->get('ADUser')
                );
                $adpass = preg_replace(
                    '#\s#',
                    '+_+',
                    self::$Host->get('ADPass')
                );
            }*/
            $fdrive = self::$Host->get('kernelDevice');
            $kernelArgsArray = array(
                "mac=$mac",
                "ftp=$ftp",
                "storage=$storage",
                "storageip=$storageip",
                "osid=$osid",
                "irqpoll",
                array(
                    'value' => "mcastrdv=$mcastrdv",
                    'active' => !empty($mcastrdv)
                ),
                array(
                    'value' => "hostname=" . self::$Host->get('name'),
                    'active' => count($clientMacs) > 0,
                ),
                array(
                    'value' => "clamav=$clamav",
                    'active' => in_array($TaskType->get('id'), array(21, 22)),
                ),
                array(
                    'value' => "chkdsk=$chkdsk",
                    'active' => $imagingTasks,
                ),
                array(
                    'value' => "img=$img",
                    'active' => $imagingTasks,
                ),
                array(
                    'value' => "imgType=$imgType",
                    'active' => $imagingTasks,
                ),
                array(
                    'value' => "imgPartitionType=$imgPartitionType",
                    'active' => $imagingTasks,
                ),
                array(
                    'value' => "imgid=$imgid",
                    'active' => $imagingTasks,
                ),
                array(
                    'value' => "imgFormat=$imgFormat",
                    'active' => $imagingTasks,
                ),
                array(
                    'value' => "PIGZ_COMP=-$PIGZ_COMP",
                    'active' => $imagingTasks,
                ),
                array(
                    'value' => 'shutdown=1',
                    'active' => $Task->get('shutdown') || $shutdown,
                ),
                array(
                    'value' => "adon=1 addomain=\"$addomain\" "
                    . "adou=\"$adou\" aduser=\"$aduser\" "
                    . "adpass=\"$adpass\"",
                    'active' => self::$Host->get('useAD'),
                ),
                array(
                    'value' => "fdrive=$fdrive",
                    'active' => self::$Host->get('kernelDevice'),
                ),
                array(
                    'value' => 'hostearly=1',
                    'active' => (
                        $hosterl
                        && $imagingTasks ?
                        true :
                        false
                    ),
                ),
                array(
                    'value' => sprintf(
                        'pct=%d',
                        (
                            is_numeric($capresz)
                            && $capresz >= 5
                            && $capresz < 100 ?
                            $capresz :
                            '5'
                        )
                    ),
                    'active' => $imagingTasks && $TaskType->isCapture(),
                ),
                array(
                    'value' => sprintf(
                        'ignorepg=%d',
                        (
                            $cappage ?
                            1 :
                            0
                        )
                    ),
                    'active' => $imagingTasks && $TaskType->isCapture(),
                ),
                array(
                    'value' => sprintf(
                        'port=%s',
                        (
                            $TaskType->isMulticast() ?
                            $MulticastSession->get('port') :
                            null
                        )
                    ),
                    'active' => $TaskType->isMulticast(),
                ),
                array(
                    'value' => sprintf(
                        'winuser=%s',
                        $Task->get('passreset')
                    ),
                    'active' => $TaskType->get('id') == '11',
                ),
                array(
                    'value' => 'isdebug=yes',
                    'active' => $Task->get('isDebug'),
                ),
                array(
                    'value' => 'debug',
                    'active' => $kdebug,
                ),
                array(
                    'value' => 'seconds='.$timeout,
                    'active' => in_array($TaskType->get('id'), range(18, 20)),
                ),
                $TaskType->get('kernelArgs'),
                $kargs,
                self::$Host->get('kernelArgs'),
            );
            if ($Task->get('typeID') == 4) {
                $Send['memtest'] = array(
					'set timeout=3 ; set default=0',
					'menuentry "Run Memtester" --class gnome-system-monitor --id bootmemtest {',
					$this->_kernel . " menutype=memtester",
					'echo "Loading kernel. . ."',
					$this->_initrd,
					'echo "Loading initrd. . ."',
					'echo "Booting kernel, please wait."',
					'}',
                );
                $this->_parseMe($Send);
            } else {
                $this->_printTasking($kernelArgsArray);
            }
        }
    }
    /**
     * Print the default information for all hosts
     *
     * @return void
     */
    public function printDefault()
    {
        if (self::$Host->isValid()
            && self::getSetting('FOG_NO_MENU')
        ) {
            $this->noMenu();
        }
        if ($this->_hiddenmenu) {
            // TODO : Nettoyer tout ça ! 
            //$this->_chainBoot(true);
            return;
        }
        $Menus = self::getClass('PXEMenuOptionsManager')->find('', '', 'id');
        $ipxeGrabs = array(
            'FOG_ADVANCED_MENU_LOGIN',
            'FOG_IPXE_BG_FILE',
            'FOG_IPXE_HOST_CPAIRS',
            'FOG_IPXE_INVALID_HOST_COLOURS',
            'FOG_IPXE_MAIN_COLOURS',
            'FOG_IPXE_MAIN_CPAIRS',
            'FOG_IPXE_MAIN_FALLBACK_CPAIRS',
            'FOG_IPXE_VALID_HOST_COLOURS',
            'FOG_PXE_ADVANCED',
            'FOG_REGISTRATION_ENABLED',
        );
        list(
            $AdvLogin,
            $bgfile,
            $hostCpairs,
            $hostInvalid,
            $mainColors,
            $mainCpairs,
            $mainFallback,
            $hostValid,
            $Advanced,
            $regEnabled
        ) = self::getSubObjectIDs(
            'Service',
            array(
                'name' => $ipxeGrabs
            ),
            'value',
            false,
            'AND',
            'name',
            false,
            ''
        );

        $showDebug = isset($_REQUEST['debug']);

        $Send['header'] = array(
                'set default=boothardisk',
            );

        $reg_string = 'NOT registered!';
        if (self::$Host->isValid()) {
            if (self::$Host->get('pending')) {
				$Send['menustart'] = array(
					'menuentry "Host is pending approval." --class pending --id info {',
					'true',
					'}',
				);
			} else {
				$Send['menustart'] = array(
					'menuentry "Host is registered as ' . self::$Host->get('name') .'!" --class reg info {',
					'true',
					'}',
				);
			}
        } else {
			$Send['menustart'] = array(
				'menuentry "Host is NOT registered! MAC='.$_REQUEST['mac'].'" --class not-reg info {',
				'true',
				'}',
				self::getSetting('FOG_QUICKREG_AUTOPOP') ? 'set default=autoreg' : '',
			);
		}
		
		$Send["DebutMenuGrub"] = array(	
			'menuentry "Boot from hard disk" --class drive-harddisk --id boothardisk {',
			'echo "Booting first local disk..."',
			'# Generate boot menu automatically',
			'configfile ${prefix}/boot-local-efi.cfg',
			'# If not chainloaded, definitely no uEFI boot loader was found.',
			'echo "No uEFI boot loader was found!"',
			'echo " => Restarting in 30 seconds"',
			'sleep 30',
			'reboot',
			'}',

			'menuentry "Run Memtester" --class gnome-system-monitor --id bootmemtest {',
			'echo "Loading kernel. . ."',
			$this->_kernel . " menutype=memtester",
			'echo "Loading initrd. . ."',
			$this->_initrd,
			'echo "Booting kernel, please wait."',
			'}',
		);

        if (self::$Host->isValid()) {
            if (self::$Host->get('pending')) {
                $Send["Approval"] = array(
                'menuentry "Approve This Host" --class fogplus --id approve {',
                'echo "Loading kernel. . ."',
                $this->_kernel . " menutype=approvehost",
                'echo "Loading initrd. . ."',
                $this->_initrd,
				'echo "Booting kernel, please wait."',
                '}',
                );
            }
        }
		
		if (!self::$Host->isValid()) {
			$Send["MilieuMenuGrub"] = array(	
				'menuentry "Perform Full Host Registration and Inventory" --class fog --id manreg {',
				'echo "Loading kernel. . ."',
				$this->_kernel . " mode=manreg",
				'echo "Loading initrd. . ."',
				$this->_initrd,
				'echo "Booting kernel, please wait."',
				'}',
				'menuentry "Quick Registration and Inventory" --class fogplus --id autoreg {',
				'echo "Loading kernel. . ."',
				$this->_kernel . " mode=autoreg",
				'echo "Loading initrd. . ."',
				$this->_initrd,
				'echo "Booting kernel, please wait."',
				'}',
				);
		} else {
			$Send["MilieuMenuGrub"] = array(	
				'menuentry "Quick host deletion" --class unreg --id unreg {',
				'echo "Loading kernel. . ."',
				$this->_kernel . " menutype=unreg",
				'echo "Loading initrd. . ."',
				$this->_initrd,
				'echo "Booting kernel, please wait."',
				'}',
                'menuentry "Update Product Key" --class fogplus --id updatekey {',
                'echo "Loading kernel. . ."',
                $this->_kernel . " menutype=updatekey",
                'echo "Loading initrd. . ."',
                $this->_initrd,
				'echo "Booting kernel, please wait."',
                '}',


				);
		};
		
		$Send["FinMenuGrub"] = array(
			'menuentry "Deploy Image" --class download --id downimage {',
				'echo "Loading kernel. . ."',
				$this->_kernel . " menutype=down",
				'echo "Loading initrd. . ."',
				$this->_initrd,
				'echo "Booting kernel, please wait."',
			'}',
			'menuentry "Join Multicast Session" --class multicast --id joinmulticast {',
				'echo "Loading kernel. . ."',
				$this->_kernel . " menutype=askmc",
				'echo "Loading initrd. . ."',
				$this->_initrd,
				'echo "Booting kernel, please wait."',
			'}',
			'menuentry "Client System Information (compatibility)" --class fog --id systeminfo {',
				'echo "Loading kernel. . ."',
				$this->_kernel . " mode=sysinfo",
				'echo "Loading initrd. . ."',
				$this->_initrd,
				'echo "Booting kernel, please wait."',
			'}',
			'menuentry "Enable GUI" --class gear --id enablegfx {',
			'set gfxgui=gfxgui=xorg',
			'echo "Ok"',
			'}',
			'menuentry "uEFI firmware setup" --class gear --id uefi-firmware {',
			'echo "Entering uEFI firmware setup..."',
			'fwsetup',
			'}',
		);
		
        $this->_parseMe($Send);
    }
}
