#!/usr/bin/perl -w
# Inventory script to fullfill data about equipment by its  Template correspondence, IP, OID
# by Bandurin DV
#use 5.010;
#use 5.010;
#use strict;
use warnings;
# use AutoLoader 'AUTOLOAD';
use JSON::RPC::Legacy::Client;
use Data::Dumper;
use Net::SNMP;

my $s1=shift|| '771072.785';
$s1=($s1=~/^\d{1,}\.(\d{1,})$/s)? $1:'NO ALARMS FOUND';

my $fault_base =<<'END';
{
-- SONET/SDH alarms
            losSonetAlarm(1),   		-- Loss Of Signal (S)
            lofSonetAlarm(2),   		-- Loss Of Frame (S)
            lopSonetAlarm(3),   		-- Loss Of Pointer (P)
            aisLineSonetAlarm(4),   	-- Alarm Indication Signal (L)
            rfiLineSonetAlarm(5),   	-- Remote Failure Indication (L)
            uneqSonetAlarm(6),  		-- Unequipped (P)
            timLine(7),             	-- Trace Indication Mismatch (S)
            slm(8),             		-- Signal Label Mismatch (P) - Defect
			sd(9),              		-- Signal Degrade (SDH only)
			sf(10),             		-- Signal Fail (SDH only)
			hwfail(11),          		-- HW Fail
            aisPathSonetAlarm(12),   	-- Alarm Indication Signal (P)
            rfiPathSonetAlarm(13),   	-- Remote Failure Indication (P)
            timPath(14),             	-- Trace Indication Mismatch (P)
			uplinkTransmitMismatch(15), -- Transceiver mismatch or removed (deprecated)
			uplinkClockSourceLol(16), 	-- Clock Source Loss of lock
			aisVtSonetAlarm(21),		-- Alarm Indication Signal (V)
			lopVtSonetAlarm(22),		-- Loss Of Pointer (V)
			rfiVtSonetAlarm(23),		-- Remote Failure Indication (V)
			timVt(24),					-- Trace Indication Mismatch (V)
			slmVt(25),					-- Signal Label Mismatch (V)
			uneqVtSonetAlarm(26),		-- Unequipped (V)
			lomVt(27),					-- Loss of Multiframe (V)

-- GFP/VCG alarms
			vcgFarLossClientSignal(101),-- Far-end Loss of Client Signal
			vcgFarLossClientSync(102),  -- Far-end Loss of Client Sync
			vcgLossAlignment(103),		-- VCG Loss of Alignment
			vcgLossMultiframe(104),		-- VCG Loss of Multiframe
			vcgLossSequence(105), 		-- VCG Loss of Sequence
			vcgGfpLossSync(106),   		-- GFP framer Loss of Sync
			vcgFarGfpLossSync(107),   	-- Far-end GFP Loss of Sync
			vcgBadGidMember(108), 		-- Bad GID of a VCAT member

-- Provisioning alarms
			provUnequipped(151),		-- Unprovisioned service
			provMismatch(152),  		-- Mismatch provisioning

-- Ethernet alarms
			ethConfigTransmitFault(201),-- Optical GbE transceiver transmit fault (deprecated)
			ethConfigLossOfSignal(202), -- Optical GbE transceiver signal detect failed
			ethConfigLinkFail(203),     -- Mac Layer Link failed
			ethConfigPcsLossSync(204),  -- PCS coding loss of sync

-- FC alarms
			fcBxPortTransmitFault(301), -- Transceiver transmit fault (deprecated)
			fcBxPortLossOfSignal(302),  -- Transceiver signal detect failed
			fcBxPortNoLink(303),		-- No link established yet.
			fcBxPortLossOfSync(304),	-- Loss of sync
			fcBxPortTransmitMismatch(306), -- Transceiver mismatch or removed (deprecated)
			fcBxPortPcsLossSync(307),   -- PCS coding loss of sync

			fcipLinkNoLink(311),		-- No link established yet.
			fcipLinkLossOfSync(312),	-- Loss of sync
			fcipSntpFailure(313),		-- SNTP failure
			fcipIpsecFailure(314),		-- IPSec failure
			fcipFarLossOfClient(315),   -- The Far-End lost the FC link

-- Escon alarms
			esconPortTransmitFault(351), -- Transceiver transmit fault (deprecated)
			esconPortLossOfSignal(352),  -- Transceiver signal detect failed
			esconPortNoLink(353),		 -- No link established yet.
			esconPortLossOfSync(354),	 -- Loss of sync

-- EDFA alarms
			edfaPumpTemperuture(401),   -- Pump temperatur is out-of-bound
			edfaHwFail(403),            -- Pump HW failure
			edfaRvcSignalDetect(404),   -- Loss of input signal
			edfaRcvPower(406),          -- Rx Power is out-of-bound
			edfaTemprature(407),        -- Edfa temperature is out-of-bound
			edfaEyeSafty(408),		    -- Eye safety alarm (available only in eye-safety mode)
			edafGainFlatness(409),	  	-- Gain flatness alarm
			edfaXmtPower(410),          -- Tx Power is out-of-bound
			edfaGain(411),              -- Edfa Gain is out-of-bound
			edfaEol(412),               -- Pump End Of Life

-- Muxponder alarms
			muxAisPath(451) ,   		-- Muxponder AIS
			muxLof(452),            	-- Muxponder LOF
			muxRdi(453),            	-- Muxponder RDI
			muxInbandFail(454),      	-- Muxponder Inband Fail
			muxTempLicense(455),        -- Muxponder Temporary Licensed
			muxNoLicense(456),         	-- Muxponder Not Licensed

-- Optical Switch alarms
			oswHwFail(470),            	-- The optical switch is defined in seep but not exist
			oswLossOfSignal(471),       -- LOS is detected on the port of the optical switch
			oswEdfaLossProp(472),

-- DCM alarms
			dcmTemp(475),            	-- The DCM tec temperature is too high
			dcmTec(476),            	-- The DCM tec is out of range
			dcmHwFault(477),            -- DCM EEPROM error 

-- Port alarms
			loopback(501),            	-- The port is in loopback
			apsForceActive(502),        -- Force Switch is active on this port
			apsManualActive(503),       -- Manual Switch is active on this port

-- CLU alarms
			cluHoldoverState(602),		-- Clu is switched to holdover 
			cluFreerunState(603),		-- Clu is in free run state
			cluBelowLevel(604),			-- Clock is below internal level
			cluFail(606),				-- Clock fail
			cluJittered(608),			-- Clock jittered
			
-- WSS alarms
			channelLowDegrade(621), 	-- OCM Power Level Parameter 2
			channelHighDegrade(622), 	-- OCM Power Level Parameter 3 
			channelLowFail(623), 		-- OCM Power Level Parameter 4 
			channelHighFail(624), 		-- OCM Power Level Parameter 5 
			unequalizedOuputPower(625), -- Failed to equalize channels output power 

-- SFP Alarms
			sfpTransmitFault(701),		-- sfp hardware problem 
			sfpRemoved(702),			-- spf is either removed or failed
			sfpMuxWlMismatch(703),		-- wl of the sfp does not match the wls of the mux 
			sfpBitRateMismatch(704),	-- the sfp bit rate does not match the implied port rate
			sfpLossOfLock(705),			-- retimer problem
			sfpSfpWlMismatch(706),		-- two sfps with the same wave length in 
			sfpLossOfLight(707),		-- no signnal detection
			sfpLaserEndOfLife(708),     -- laser end of life indication
			sfpMuxSpacingMismatch(709),	-- spacing of the sfp does not match the spacing of the mux 
			sfpHardwareFault(710),		-- wrong sfp crc
			sfpBlocked(711),			-- the sfp is blocked
			sfpLossPropagation(712), 	-- shut laser due to a problem with the mate sfp
			sfpUnknownType(713), 		-- unknown sfp type warning - doesn't shut the laser
			sfpTxLossOfLock(714),		-- loss of lock on the tx CDR
			
			sfpHighTemp(720),			-- internal temperature exceeds high alarm level.
			sfpLowTemp(721),			-- internal temperature is below low alarm level.
			sfpHighTxPower(726),		-- TX output power exceeds high alarm level.
			sfpLowTxPower(727),			-- TX output power is below low alarm level.
			sfpHighRxPower(728),		-- Received Power exceeds high alarm level.
			sfpLowRxPower(729),			-- Received Power is below low alarm level.
			sfpHighLaserTemp(730),		-- (15xy) laser TEC current exceeds high alarm level.
			sfpLowLaserTemp(731),		-- (15xy) laser TEC current exceeds low alarm level.
			sfpHighLaserWl(732),		-- (15xy) laser wavelength exceeds high alarm level.
			sfpLowLaserWl(733),			-- (15xy) laser wavelength is below low alarm level.

-- XFP Alarms
			xfpTxNR(734),
			xfpTxCdrNotLocked(735),
			xfpRxNR(736),
			xfpRxCdrNotLocked(737),

-- OTN Alarms
			otnFecExc(750),				-- FEC-EXC Trail Excessive Errors (Early FEC) > 10-4
            otnFecDeg(751),				-- FEC-DEG Trail Degraded Errors (Early FEC) > 10-8
			otnOtuDeg(752),				-- S-DEG Section- Degraded Performance. Based on SM BIP
            otnOduDeg(753),				-- P-DEG Path- Degraded Performance. Based on PM BIP
			otnLos(754),				-- LOS Loss of Signal
			otnLof(755),				-- LOF Loss of Frame. OOF present for at least 3ms
			otnLom(756),				-- LOM Loss of Multiframe; OOM present for at least 3ms
			otuAis(757),				-- S-AIS Section-Alarm Indication Signal
			otuBdi(758),				-- S-BDI Section-Backward Defect Indicator
			otuTtim(759),				-- S-TTIM Section-Trail Trace Identifier Mismatch (SAPI/DAPI)
			oduAis(780),				-- P-AIS Path-Alarm Indication Signal
			oduOci(781),				-- P-OCI Path-Open Connection indicator
			oduLck(782),				-- P-LCK Path-Locked. Path Locked active
			oduBdi(783),				-- P-BDI Path-Backward Error indicator.
			oduTtim(784),				-- P-TTIM Path-Trail Trace Identifier Mismatch (SAPI/DAPI)
            oduPtm(785),				-- P-PTM Path Payload Type Mismatch
			oduApsMismatch(786),		-- ODU Path APS Mismatch
			otnOtuFail(787),			-- S-EXC Section- Excessive Errors. Based on SM BIP
            otnOduFail(788),			-- P-EXC Path- Excessive Errors. Based on PM BIP
			

-- NE alarms
			entityRemoved(801), 		-- Card is removed from the slot           
			entityClockFail(803),		-- Clock Failure    
			entityHwTxFail(804),		-- HW or Tx failure
			entitySwMismatch(806),		-- SW version mismatch detected
			entitySwUpgrade(807),		-- Software Upgrade in progress
			entitySwInvalidBank(808),	-- Software Bank is invalid
			entityIpLanPending(820),	-- new LAN IP address is pending
			entityIpOscPending(821),	-- new OSC IP address is pending
			nePowerFault(902),			-- Power supply unit has failed
			neFanFault(903),			-- Fan unit has failed
			neLowVoltagePower(904),		-- The voltage of the Power Supply is too low
			entitySwUpgradeFail(905),	-- SW Upgrade Failed
			entityRadiusPrimFail(906),	-- Radius Primary Server failed
			entityRadiusSecFail(907),	-- Radius Secondary Server failed
			entityDbRestoreFail(908),	-- Database Restore Failed
			entityDbRestoreInProgress(909),	-- Database Restore In Progress
			entitySntpFail(910),		-- SNTP server failure 
			
-- Misc
			dcActive(1001),	  			-- An alarm on the input dry contact
			lcpDown(1002),	  			-- The LCP link is down
			ncpDown(1003),	  			-- The NCP link is down
			rtcFailure(1004)			-- RTC failure
       }
END

print $fault_base=~/^\s{1,}(\w{1,})\($s1\)[,\s\t]{1,}--[\s\t]{0,}([\w\W]{1,}?)\n/m ? $1."(".$2.")":"NO ALARMS FOUND"; 	 	