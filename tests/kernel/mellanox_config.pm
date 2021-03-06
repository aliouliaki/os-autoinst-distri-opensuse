# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Mellanox Link protocol config
# This configures the interfaces according to the
# variable MLX_PROTOCOL. By default ETH if not set.
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;
use ipmi_backend_utils;
use power_action_utils 'power_action';
use version_utils 'is_sle';
use serial_terminal 'select_virtio_console';

our $device1 = '/dev/mst/mt4119_pciconf0';
our $device2 = '/dev/mst/mt4119_pciconf0.1';

sub show_links {
    assert_script_run("mlxconfig -d $device1 q|grep LINK_TYPE");
    assert_script_run("mlxconfig -d $device2 q|grep LINK_TYPE");
}

sub run {
    select_console 'root-ssh' if (check_var('BACKEND', 'ipmi'));
    select_virtio_console()   if (check_var('BACKEND', 'qemu'));

    my $mft_version = get_required_var('MFT_VERSION');
    my $protocol = get_var('MLX_PROTOCOL') || 2;

    if (is_sle('>=15')) {
        my $GA_REPO = 'http://download.suse.de/ibs/SUSE:/SLE-15:/GA/standard/SUSE:SLE-15:GA.repo';
        zypper_call("ar -f -G $GA_REPO");
    }
    zypper_call('--quiet in kernel-source rpm-build', timeout => 200);

    # Install Mellanox Firmware Tool (MFT)
    assert_script_run("wget http://www.mellanox.com/downloads/MFT/" . $mft_version . ".tgz");
    assert_script_run("tar -xzvf " . $mft_version . ".tgz");
    assert_script_run("rm " . $mft_version . ".tgz");
    assert_script_run("./" . $mft_version . "/install.sh");
    assert_script_run("mst start");

    # List network devices
    assert_script_run("lspci|egrep -i 'network|ethernet'");

    if (check_var('BACKEND', 'ipmi')) {
        if (script_run("lspci|grep -i mellanox") != 0) {
            die "There is no Mellanox card here";
        }
        if (script_run("ls " . $device1) != 0) {
            die "The directory $device1 doesn't exist";
        }
        if (script_run("ls " . $device2) != 0) {
            die "The directory $device2 doesn't exist";
        }
        # Change Link protocol
        record_info("INFO", "Wanted Link protocol is $protocol");
        show_links();
        assert_script_run("mlxconfig -y -d $device1 set LINK_TYPE_P1=$protocol LINK_TYPE_P2=$protocol");
        assert_script_run("mlxconfig -y -d $device2 set LINK_TYPE_P1=$protocol LINK_TYPE_P2=$protocol");
        show_links();

        # Reboot system
        power_action('reboot', textmode => 1, keepconsole => 1);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
