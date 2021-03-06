# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install IPA tool
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "opensusebasetest";
use strict;
use testapi;
use utils;
use registration 'add_suseconnect_product';
use serial_terminal 'select_virtio_console';
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);


sub run {
    my ($self) = @_;

    select_virtio_console();

    if (is_sle) {
        my $modver = get_required_var('VERSION') =~ s/-SP\d+//gr;
        add_suseconnect_product('sle-module-public-cloud', $modver);
    }


    my $tools_repo = get_var('PUBLIC_CLOUD_TOOLS_REPO', '');
    if ($tools_repo eq '') {
        my $dist    = get_required_var('DISTRI');
        my $version = get_required_var('VERSION');
        if (is_sle) {
            $dist = 'SLE';
            $version =~ s/-/_/;
        }
        elsif (is_tumbleweed) {
            $dist = 'openSUSE';
        }
        elsif (is_leap) {
            $dist = 'openSUSE_Leap';
        }
        $tools_repo = 'http://download.opensuse.org/repositories/Cloud:/Tools/' . $dist . "_" . $version . '/Cloud:Tools.repo';
    }
    zypper_call('ar ' . $tools_repo);
    zypper_call('--gpg-auto-import-keys in python3-ipa python3-ipa-tests');

    # WAR install awscli from pip instead of using the package bsc#1095041
    zypper_call('in gcc python3-pip');
    if (is_opensuse) {
        zypper_call('in python3-devel');
        assert_script_run("pip3 install pycrypto");
    }
    assert_script_run("pip3 install awscli");
    assert_script_run("pip3 install keyring");

    # Create some directories, ipa will need them
    assert_script_run("mkdir -p ~/ipa/tests/");
    assert_script_run("mkdir -p .config/ipa");
    assert_script_run("touch .config/ipa/config");
    assert_script_run("ipa list");
    assert_script_run("ipa --version");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

=head1 Discussion

Install IPA tool in SLE image. This image gets published and can be used 
for specific tests for azure, amazon and google CSPs.

=head1 Configuration

=head2 INSTALL_IPA

Activate this test module by setting this variable.

=head2 PUBLIC_CLOUD_TOOLS_REPO

The URL to the cloud:tools repo (optional). 
(e.g. http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Tumbleweed/Cloud:Tools.repo)

=cut
