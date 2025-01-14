#!/vendor/bin/sh

type=`getprop vendor.asus.dongletype`
event=`getprop vendor.asus.dongleevent`
accy_gen=`getprop vendor.asus.accy_gen`
inbox_fwmode_path="/sys/class/leds/aura_inbox/fw_mode"
echo "[EC_HID] YodaDongleSwitch, type $type, event $event, accy_gen $accy_gen" > /dev/kmsg
retry=0
retry_tp=0
pdretry=0

function reset_accy_fw_ver(){
	setprop vendor.inbox.aura_fwver 0
	setprop vendor.station2.ec_fwver 0
	setprop vendor.station3.ec_fwver 0
	setprop vendor.station.aura_fwver 0
	setprop vendor.station.tp_fwver 0
	setprop vendor.station.dp_fwver 0
	setprop vendor.dt.aura_fwver 0
	setprop vendor.dt.power_fwver 0
	setprop vendor.station.pd_fwver 0
	setprop vendor.dt.pd_fwver 0
	setprop vendor.asus.accy.fw_status 000000
	setprop vendor.asus.accy.fw_status2 000000
	setprop vendor.asus.dt.ac_power "none"
	setprop vendor.oem.asus.inboxid 0
	setprop vendor.oem.asus.stationid 0
	setprop vendor.oem.asus.dtid 0
	setprop vendor.dt.landetect 0
}

# Define rmmod function
function remove_mod(){

	if [ -n "$1" ]; then
		echo "[EC_HID] remove_mod $1" > /dev/kmsg
	else
		exit
	fi

	test=1
	while [ "$test" == 1 ]
	do
		rmmod $1
		ret=`lsmod | grep $1`
		if [ "$ret" == "" ]; then
			echo "[EC_HID] rmmod $1 success" > /dev/kmsg
			test=0
		else
			echo "[EC_HID] rmmod $1 fail" > /dev/kmsg
			test=1
			sleep 0.5
		fi
	done
}

function check_accy_fw_ver(){

	echo "[EC_HID] Get Dongle FW Ver, type $type" > /dev/kmsg

	if [ "$type" == "1" ]; then

		if [ "$accy_gen" == "1" ]; then			# for factory test, it will be deleted later.
			setprop vendor.asus.accy.fw_status 000000
		else
			fw_mode=`cat /sys/class/leds/aura_inbox/fw_mode`
			echo "[EC_HID] InBox fw_mode =$fw_mode " > /dev/kmsg
			if [ "$fw_mode" == "1" ]; then
				inbox_unique_id=`cat /sys/class/leds/aura_inbox/unique_id`
				setprop vendor.oem.asus.inboxid $inbox_unique_id
				inbox_aura=`cat /sys/class/leds/aura_inbox/fw_ver`
				setprop vendor.inbox.aura_fwver $inbox_aura

				# check FW need update or not
				aura_fw=`getprop vendor.asusfw.inbox.aura_fwver`
				echo "[EC_HID] InBox inbox_aura = $inbox_aura  aura_fw = $aura_fw"  > /dev/kmsg
				if [ "$inbox_aura" == "$aura_fw" ]; then
					setprop vendor.asus.accy.fw_status 000000
				elif [ "$inbox_aura" == "i2c_error" ]; then
					echo "[EC_HID] InBox AURA_SYNC FW Ver Error" > /dev/kmsg
					setprop vendor.asus.accy.fw_status 000000
				else
					setprop vendor.asus.accy.fw_status 100000
				fi
			elif [ "$fw_mode" == "2" ]; then
				setprop vendor.asus.accy.fw_status 100000
			else # the wrong mode
				#Todo:reset
				echo 0 > /sys/class/leds/aura_inbox/aura_fan_en
				echo 1 > /sys/class/leds/aura_inbox/aura_fan_en
				fw_mode=`cat /sys/class/leds/aura_inbox/fw_mode`
				if [ "$fw_mode" == "1" ]; then
					inbox_aura=`cat /sys/class/leds/aura_inbox/fw_ver`
					setprop vendor.inbox.aura_fwver $inbox_aura

					# check FW need update or not
					aura_fw=`getprop vendor.asusfw.inbox.aura_fwver`
					if [ "$inbox_aura" == "$aura_fw" ]; then
						setprop vendor.asus.accy.fw_status 000000
					elif [ "$inbox_aura" == "i2c_error" ]; then
						echo "[EC_HID] InBox AURA_SYNC FW Ver Error" > /dev/kmsg
						setprop vendor.asus.accy.fw_status 000000
					else
						setprop vendor.asus.accy.fw_status 100000
					fi
				elif [ "$fw_mode" == "2" ]; then
					setprop vendor.asus.accy.fw_status 100000
				else
					echo "[EC_HID] inbox fw_mode is wrong." > /dev/kmsg
				fi
			fi
		fi
	elif [ "$type" == "2" ]; then
		station_aura=`cat /sys/class/leds/aura_station/fw_ver`
		setprop vendor.station.aura_fwver $station_aura

		((station_ec=`cat /sys/class/ec_i2c/dongle/device/fw_ver`))
		#station_ec=`cat /sys/class/ec_i2c/dongle/device/fw_ver`
		if [ "$station_ec" -lt "535" ]; then
			echo "[EC_HID] EC FW $station_ec is too old, force set as StationII" > /dev/kmsg
			setprop vendor.station.generation 2
			setprop vendor.station2.ec_fwver $station_ec
		else
			station_hwid=`cat /sys/class/ec_i2c/dongle/device/hw_id`
			if [ "$station_hwid" == "0x2" ]; then
				setprop vendor.station.generation 2
				setprop vendor.station2.ec_fwver $station_ec
			elif [ "$station_hwid" == "0x3" ]; then
				setprop vendor.station.generation 3
				setprop vendor.station3.ec_fwver $station_ec
			else
				setprop vendor.station.generation 2
				setprop vendor.station2.ec_fwver $station_ec
			fi
		fi

		station_ssn=`cat /sys/class/ec_i2c/dongle/device/ec_ssn`
		setprop vendor.oem.asus.stationid $station_ssn

#		station_tp_goodix=`cat sys/devices/platform/goodix_ts_station.0/chip_info|sed -n '3 p' |awk -F ":" '{print $NF}'`
#		if [ "$station_tp_goodix" != "" ]; then
#			while [ "$station_tp_goodix" == "00.00.00.00" -a "$retry_tp" -lt 2 ]
#			do
#				echo "[EC_HID] retry check tp ver. $retry_tp" > /dev/kmsg
#				retry_tp=$(($retry_tp+1))
#				station_tp_goodix=`cat sys/devices/platform/goodix_ts_station.0/chip_info|sed -n '3 p' |awk -F ":" '{print $NF}'`
#			done
#			station_tp=$station_tp_goodix
#			station_tp_cfg=`cat /sys/devices/platform/goodix_ts_station.0/read_cfg|sed -n '1 p'|awk 'BEGIN{FS=" "}{print $1}'`
#			tp_phone_fw=`cat sys/devices/platform/goodix_ts.0/chip_info|sed -n '3 p' |awk -F ":" '{print $NF}'`
#			tp_fw=$tp_phone_fw
#		else
#			station_tp="version_wrong"
#		fi
#		setprop vendor.station.tp_fwver "$station_tp CFG:$((16#$station_tp_cfg))"
#		setprop vendor.asusfw.station.tp_fwver $tp_fw

		station_dp=`cat /sys/class/ec_i2c/dongle/device/DP_FW`
		setprop vendor.station.dp_fwver $station_dp

		display_id=`cat /sys/class/ec_i2c/dongle/device/display_id`

		if [ "$display_id" == "1" ]; then
			echo "[EC_HID][Switch] dimming node , this is PR2 Panel !!" > /dev/kmsg
		elif [ "$display_id" == "0" ]; then
			echo "[EC_HID][Switch] normal node , this is PR1 Panel !!" > /dev/kmsg
		else
			echo "[EC_HID][Switch] can not read any panel information !!" > /dev/kmsg
		fi

		st_pdfw=`cat /sys/class/usbpd/usbpd0/pdfw`

		while [ "$st_pdfw" == "ffff" -a "$retry" -lt 2 ]
		do
			echo "[PD_HID] retry check ver." > /dev/kmsg
			retry=$(($retry+1))
			st_pdfw=`cat /sys/class/usbpd/usbpd0/pdfw`
		done

		# check FW need update or not
		aura_fw=`getprop vendor.asusfw.station.aura_fwver`
		if [ "$station_aura" == "$aura_fw" ]; then
			aura_status=0
		elif [ "$station_aura" == "i2c_error" ]; then
			echo "[EC_HID] Station AURA_SYNC FW Ver Error" > /dev/kmsg
			aura_status=0
		else
			aura_status=1
		fi

		station_gen=`getprop vendor.station.generation`
		if [ "$station_gen" == "2" ]; then
			ec_fw=`getprop vendor.asusfw.station2.ec_fwver`
		elif [ "$station_gen" == "3" ]; then
			ec_fw=`getprop vendor.asusfw.station3.ec_fwver`
		else
			ec_fw=`getprop vendor.asusfw.station2.ec_fwver`
		fi

		if [ "$station_ec" == "$ec_fw" ]; then
			ec_status=0
		elif [ "$station_ec" == "i2c_error" ]; then
		#elif [ "$station_ec" == "HID_not_connect" ]; then
			echo "[EC_I2C] Station EC FW Ver Error" > /dev/kmsg
			ec_status=0
		else
			ec_status=1
		fi

#		if [ "$station_gen" == "2" ]; then
#			if [ "$station_tp" == "$tp_fw" ]; then
#				echo "[EC_HID] Station TP FW Ver is the newest" > /dev/kmsg
#				tp_status=0
#			elif [ "$station_tp" == "i2c_error" ] || [ "$station_tp" == "version_wrong" ]; then
#				echo "[EC_HID] Station TP FW Ver Error" > /dev/kmsg
#				tp_status=0
#			else
#				echo "[EC_HID] Station TP FW Ver update" > /dev/kmsg
#				tp_status=1
#			fi
#		elif [ "$station_gen" == "3" ]; then
#			echo "[EC_HID] Station 3, temporary skip tp fw check" > /dev/kmsg
#			tp_status=0
#		fi

		pd_fw=`getprop vendor.asusfw.station.pd_fwver`

		echo "[PD_HID] st_pdfw " > /dev/kmsg

		if [ "$st_pdfw" == "$pd_fw" ]; then
			echo "[PD_HID] do not update!!!" > /dev/kmsg
			pd_status=0
			setprop vendor.station.pd_fwver "$st_pdfw"
		elif [ "$st_pdfw" == "ffff" ]; then

			echo "[PD_HID] PD FW Ver Error" > /dev/kmsg

			while [ "$(lsusb | grep -E "048d:52db")" == "" -a "$pdretry" -lt 3 ]
			do
				pdretry=$(($pdretry+1))
				echo "[PD_HID] retry check loader." > /dev/kmsg
				sleep 1
			done
			
			if [ "$pdretry" -ge 3 ];then
				echo "[PD_HID] PD do not show update !!!" > /dev/kmsg
				pd_status=0
				setprop vendor.station.pd_fwver "0"
			else
				echo "[PD_HID] PD loader mode need show update !!!" > /dev/kmsg
				pd_status=1
				setprop vendor.station.pd_fwver "0"
			fi
		else
			pd_status=1
			setprop vendor.station.pd_fwver "$st_pdfw"
		fi

		tp_status=`getprop vendor.asusfw.station.tp_status`
		while [ "$tp_status" == "3" -a "$retry" -lt "10" ]
		do
			retry=$(($retry+1))
			sleep 0.3
			tp_status=`getprop vendor.asusfw.station.tp_status`
			echo "[EC_HID][Touch] Retry tp update $retry, check tp status: $tp_status" > /dev/kmsg
		done

		if [ "$tp_status" == "3" ]; then
			echo "[EC_HID][Touch] Check tp update error" > /dev/kmsg
			tp_status=0
		fi
		echo "[EC_HID][Touch] Check tp status: $tp_status" > /dev/kmsg

		setprop vendor.asus.accy.fw_status2 "$pd_status"00000

		setprop vendor.asus.accy.fw_status 0"$aura_status""$tp_status""$ec_status"00

	elif [ "$type" == "3" ]; then
		dt_aura=`cat /sys/class/leds/aura_dock/fw_ver`
		setprop vendor.dt.aura_fwver $dt_aura

		dt_power=`cat /sys/class/leds/DT_power/fw_ver`
		setprop vendor.dt.power_fwver $dt_power

		dt_pdfw=`cat /sys/class/usbpd/usbpd0/pdfw`

		while [ "$dt_pdfw" == "ffff" -a "$retry" -lt 2 ]
		do
			echo "[PD_DT] retry check ver. $retry" > /dev/kmsg
			retry=$(($retry+1))
			dt_pdfw=`cat /sys/class/usbpd/usbpd0/pdfw`
		done

		if [ "$dt_pdfw" == "ffff" ]; then
			power_role=`cat /sys/class/usbpd/usbpd0/current_pr`
			if [ "$power_role" == "source" ]; then
				echo "[PD_DT] PD FW Error reflash FW." > /dev/kmsg
				dt_pdfw="0"
				setprop vendor.asus.dt.ac_power 1
				setprop vendor.asus.accy.fw_status2 000100
			else
				dt_pdfw=`getprop vendor.asusfw.dt.pd_fwver`
			fi
		fi
		setprop vendor.dt.pd_fwver "$dt_pdfw"

		# check FW need update or not
		aura_fw=`getprop vendor.asusfw.dt.aura_fwver`
		if [ "$dt_aura" == "$aura_fw" ]; then
			aura_status=0
		elif [ "$dt_aura" == "i2c_error" ]; then
			echo "[EC_HID] DT AURA_SYNC FW Ver Error" > /dev/kmsg
			aura_status=0
		else
			#retry
			sleep 1
			echo "[EC_HID] DT AURA need update. check again." > /dev/kmsg
			dt_aura=`cat /sys/class/leds/aura_dock/fw_ver`
			setprop vendor.dt.aura_fwver $dt_aura
			if [ "$dt_aura" == "$aura_fw" ]; then
				aura_status=0
			elif [ "$dt_aura" == "i2c_error" ]; then
				echo "[EC_HID] DT AURA_SYNC FW Ver Error" > /dev/kmsg
				aura_status=0
			else
				echo "[EC_HID] DT AURA need update after check second." > /dev/kmsg
				aura_status=1
			fi
		fi

		power_fw=`getprop vendor.asusfw.dt.power_fwver`
		if [ "$dt_power" == "$power_fw" ]; then
			power_status=0
		elif [ "$dt_power" == "i2c_error" ]; then
			echo "[EC_HID] DT Power EC FW Ver Error" > /dev/kmsg
			power_status=0
		else
			power_status=1
		fi

		setprop vendor.asus.accy.fw_status 0000"$aura_status""$power_status"
	fi

	echo "[EC_HID] Get Dongle FW Ver done." > /dev/kmsg
}


bootmode=`getprop ro.bootmode`
if [ "$bootmode" == "charger" ]
then
	if [ "$type" != "2" ]
	then
		remove_mod station_key
	fi
fi


if [ "$type" == "0" ]; then
	exit

elif [ "$type" == "1" ]; then
	echo "[EC_HID][Switch] InBox" > /dev/kmsg


	if [ "$accy_gen" == "1" ]; then			# for factory test, it will be deleted later.
		insmod /vendor/lib/modules/ene_8k41_inbox.ko
		insmod /vendor/lib/modules/nct7802.ko
	else						# for normal image.
		insmod /vendor/lib/modules/ml51fb9ae_inbox.ko
		sleep 1
	fi
	

	if [ ! -f "$inbox_fwmode_path" ]; then
		echo "[EC_HID][Switch]the driver is not ok,maybe it is the 1st inbox" > /dev/kmsg
		echo 14 > /sys/class/ec_hid/dongle/device/sync_state
	else
		echo "[EC_HID][Switch]the inbox driver is ok" > /dev/kmsg
		# Close Phone aura
		echo 0 > /sys/class/leds/aura_sync/mode
		echo 1 > /sys/class/leds/aura_sync/apply
		echo 0 > /sys/class/leds/aura_sync/VDD

		# do not add any action behind here
		setprop vendor.aura.donglechmod 1
		##start DongleFWCheck
		check_accy_fw_ver;
		echo 1 > /sys/class/ec_hid/dongle/device/sync_state
	fi 
elif [ "$type" == "2" ]; then
	echo "[EC_HID][Switch] Station, Event $event" > /dev/kmsg

	# Check Station Dongle Event
	if [ "$event" == "1" ]; then
		echo "[EC_HID][Switch] ENE 6K7750 Force upgrade" > /dev/kmsg

		PID=`ps -ef| grep -w "station_fw_update.sh" | grep -v "grep" | awk '{print $2}'`
		kill -9 $PID

		# Give Dummy EC information
		setprop vendor.station.hwid 0x2
		setprop vendor.station.generation 2
		setprop vendor.station2.ec_fwver 000

		setprop vendor.asus.accy.fw_status 000100

		# do not add any action behind here
		echo 7 > /sys/class/ec_hid/dongle/device/sync_state
		exit

	elif [ "$event" == "2" ]; then
		echo "[EC_HID][Switch] Station Low Battery" > /dev/kmsg

		# force reset accy FW
		reset_accy_fw_ver;

		# close HID keyboard state
	#	echo 0 > /sys/class/ec_hid/dongle/device/keyboard_enable

		# do not add any action behind here
		echo 12 > /sys/class/ec_hid/dongle/device/sync_state
		exit

	elif [ "$event" == "3" ]; then
		echo "[EC_HID][Switch] Station Shutdown & Virtual remove" > /dev/kmsg

		# force reset accy FW
		reset_accy_fw_ver;

		# Remove all driver
	#	echo 0 > /sys/bus/i2c/devices/2-0022/lightup
	#	setprop sys.stn.regenfw 0
	#	remove_mod station_focaltech_touch
	#	echo 0 > /proc/driver/tfa9894_fw_load
	#	remove_mod ene_8k41_pogo
		remove_mod station_key

		# close HID keyboard state
	#	echo 0 > /sys/class/ec_hid/dongle/device/keyboard_enable

		# do not add any action behind here
	#	setprop vendor.aura.donglechmod 0
		echo 12 > /sys/class/ec_hid/dongle/device/sync_state

		exit
	fi
	
	echo 0 > /sys/class/ec_hid/dongle/device/is_ec_has_removed

	echo 1 > /sys/class/ec_hid/dongle/device/pogo_sync_key

	echo 11 > /sys/class/ec_hid/dongle/device/sync_state
	##insmod /vendor/lib/modules/iris3_i2c.ko
	#echo 1 > /sys/bus/i2c/devices/2-0022/lightup
	#setprop sys.stn.regenfw 1
	#echo 1 > /proc/driver/tfa9894_fw_load
	#insmod /vendor/lib/modules/ene_8k41_pogo.ko
	#insmod /vendor/lib/modules/ene_8k41_station.ko
	insmod /vendor/lib/modules/station_key.ko
	#insmod /vendor/lib/modules/ec_i2c_interface.ko
	insmod /vendor/lib/modules/ene_6k582_station.ko
	#insmod /vendor/lib/modules/station_focaltech_touch.ko
	insmod /vendor/lib/modules/station_goodix_touch.ko

	station_HWID=`cat /sys/class/ec_i2c/dongle/device/hw_id`
	echo "[EC_HID] Station HWID is $station_HWID" > /dev/kmsg
	setprop vendor.station.hwid $station_HWID

	setprop vendor.ec_i2c.donglechmod 1

	# Enable HID keyboard
	#echo 1 > /sys/class/ec_hid/dongle/device/keyboard_enable

	# Close Phone aura
	echo 0 > /sys/class/leds/aura_sync/mode
	echo 1 > /sys/class/leds/aura_sync/apply
	echo 0 > /sys/class/leds/aura_sync/VDD

	# do not add any action behind here
	#setprop vendor.aura.donglechmod 2
	##start DongleFWCheck
	check_accy_fw_ver;

	# Sync Touch recovery status
	touch_recovery=`cat /sys/class/ec_hid/dongle/device/touch_recovery`

	setprop vendor.asus.station.touch_recovery "$touch_recovery"

	echo 2 > /sys/class/ec_hid/dongle/device/sync_state
	echo 0 > /sys/class/ec_hid/dongle/device/pogo_sync_key

	# Monitor Touch recovery status +++
	retry=0
	while [ "$touch_recovery" == "1" -a "$retry" -lt 5 ]
	do
		retry=$(($retry+1))
		sleep 4

		echo "[EC_HID] retry check $retry touch_recovery" > /dev/kmsg
		touch_recovery=`cat /sys/class/ec_hid/dongle/device/touch_recovery`

		if [ "$touch_recovery" == "0" ]; then
			echo "[EC_HID] Touch recovery success!!!" > /dev/kmsg
			setprop vendor.asus.station.touch_recovery 0
			exit
		elif [ "$touch_recovery" == "2" ]; then
			echo "[EC_HID] Touch recovery fail!!!" > /dev/kmsg
			setprop vendor.asus.station.touch_recovery 2
			exit
		fi

		if [ "$retry" -eq 5 ]; then
			echo "[EC_HID] check touch_recovery timeout!!!" > /dev/kmsg
			setprop vendor.asus.station.touch_recovery 2
		fi
	done

elif [ "$type" == "3" ]; then
	echo "[EC_HID][Switch] DT" > /dev/kmsg
	insmod /vendor/lib/modules/ene_8k41_dt.ko
	insmod /vendor/lib/modules/ene_8k41_power.ko
	insmod /vendor/lib/modules/nct7802.ko

	#rmmod /vendor/lib/modules/station_focaltech_touch.ko

	AC_type=`cat /sys/class/leds/DT_power/Check_AC`
	if [ "$AC_type" == "0" ]; then
		echo "[EC_HID][Switch] DT AC is not 30W!!" > /dev/kmsg
		setprop vendor.asus.dt.ac_power 0
	else
		echo "[EC_HID][Switch] DT AC is 30W!!" > /dev/kmsg
		setprop vendor.asus.dt.ac_power 1
	fi

	# Close Phone aura
	echo 0 > /sys/class/leds/aura_sync/mode
	echo 1 > /sys/class/leds/aura_sync/apply
	echo 0 > /sys/class/leds/aura_sync/VDD

	# do not add any action behind here
	setprop vendor.aura.donglechmod 3
	##start DongleFWCheck
	check_accy_fw_ver;

	echo 3 > /sys/class/ec_hid/dongle/device/sync_state
elif [ "$type" == "4" ]; then
	echo "[EC_HID][Switch] Type Error!!" > /dev/kmsg

	#reset_accy_fw_ver;
	# do not add any action behind here
	echo 4 > /sys/class/ec_hid/dongle/device/sync_state

else
	echo "[EC_HID][Switch] Error Type $type" > /dev/kmsg
	echo 0 > /sys/class/ec_hid/dongle/device/pogo_mutex
fi
