#
# spec file for package webyast-ldap
#
# Copyright (c) 2008 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# norootforbuild
Name:           rubygem-webyast-ldap
Version:        0.1
Release:        0
%define mod_name webyast-ldap
%define mod_full_name %{mod_name}-%{version}
#
Group:          Productivity/Networking/Web/Utilities
License:        GPL-2.0	
#
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  rubygems_with_buildroot_patch
%rubygems_requires
BuildRequires:	webyast-base >= 0.3
BuildRequires:	webyast-base-testsuite
BuildRequires:	rubygem-restility
PreReq:	        webyast-base >= 0.3

URL:            http://en.opensuse.org/Portal:WebYaST
Summary:        WebYaST - service for configuration of LDAP client
Source:         %{mod_full_name}.gem
Source1:	org.opensuse.yast.modules.yapi.ldap.policy
Source2:	LDAP.pm

# LDAP.pm is using yast2-ldap-client API
Requires:	yast2-ldap-client pam_ldap nss_ldap
# reasonable PATH set (bnc#617442) 
Requires:       yast2-dbus-server >= 2.17.3

%package doc
Summary:        RDoc documentation for %{mod_name}
Group:          Development/Languages/Ruby
Requires:       %{name} = %{version}
%description doc
Documentation generated at gem installation time.
Usually in RDoc and RI formats.

%package testsuite
Summary:        Test suite for %{mod_name}
Group:          Development/Languages/Ruby
Requires:       %{name} = %{version}
%description testsuite
Test::Unit or RSpec files, useful for developers.


%description
WebYaST - Plugin providing REST service for configuration of LDAP client

Authors:
--------
    Jiri Suchomel <jsuchome@novell.com>

%description testsuite
This package contains complete testsuite for webyast-ldap package.
It's only needed for verifying the functionality of the module and it's not
needed at runtime.

%prep


%build

%check
# run the testsuite
%webyast_run_plugin_tests

%install

%gem_install %{S:0}

# Policies
mkdir -p $RPM_BUILD_ROOT/usr/share/%{webyast_polkit_dir}
install -m 0644 %SOURCE1 $RPM_BUILD_ROOT/usr/share/%{webyast_polkit_dir}

#YaPI
mkdir -p $RPM_BUILD_ROOT/usr/share/YaST2/modules/YaPI/
cp %{SOURCE2} $RPM_BUILD_ROOT/usr/share/YaST2/modules/YaPI/

%webyast_build_restdoc public/ldap/restdoc

# remove empty public
rm -rf $RPM_BUILD_ROOT/%{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_full_name}/public

%webyast_build_plugin_assets


%clean
%{__rm} -rf $RPM_BUILD_ROOT

%post
# granting all permissions for the web user
/usr/sbin/grantwebyastrights --user root --action grant > /dev/null
/usr/sbin/grantwebyastrights --user %{webyast_user} --action grant > /dev/null
%webyast_update_assets

%postun
%webyast_update_assets

%files
%defattr(-,root,root,-)
%{_libdir}/ruby/gems/%{rb_ver}/cache/%{mod_full_name}.gem
%{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_full_name}/
%exclude %{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_full_name}/test
%{_libdir}/ruby/gems/%{rb_ver}/specifications/%{mod_full_name}.gemspec

# precompiled assets
%dir %{webyast_dir}/public/assets
%{webyast_dir}/public/assets/*

# restdoc documentation
%dir %{webyast_dir}/public/ldap
%{webyast_dir}/public/ldap/restdoc

# YaPI dir
%dir /usr/share/YaST2/
%dir /usr/share/YaST2/modules/
%dir /usr/share/YaST2/modules/YaPI/
/usr/share/YaST2/modules/YaPI/LDAP.pm

%dir /usr/share/%{webyast_polkit_dir}
%attr(644,root,root) %config /usr/share/%{webyast_polkit_dir}/org.opensuse.yast.modules.yapi.ldap.policy

%files doc
%defattr(-,root,root,-)
%doc %{_libdir}/ruby/gems/%{rb_ver}/doc/%{mod_full_name}/

%files testsuite
%defattr(-,root,root,-)
%{_libdir}/ruby/gems/%{rb_ver}/gems/%{mod_full_name}/test

%changelog
