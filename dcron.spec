Name:      dcron
Version:   1.0.0
Release:   1
Summary:   a simple way to make cron distributed
Group:     dcron
License:   Apache2
Source0:   dcron-1.0.0.tar.gz
BuildRoot: /var/tmp/tail2kafka
#BuildRequires: libcurl-devel >= 7.19.7
#BuildRequires: openssl-devel >= 1.0.1e-30
#Requires: libcurl >= 7.19.7
#Requires: openssl >= 1.0.1e-30
AutoReqProv: no

%description
a simple way to make cron distributed

%prep
%setup -q

%build
make clean
make

%install
mkdir -p $RPM_BUILD_ROOT/usr/local/bin
cp build/dcron  $RPM_BUILD_ROOT/usr/local/bin

%files
%defattr(-,root,root)
/usr/local/bin

%post
mkdir -p /var/lib/dcron
mkdir -p /var/log/dcron

%clean
rm -rf $RPM_BUILD_ROOT

%changelog
* Tue Mar 20 2018 zzyongx <iamzhengzhiyong@gmail.com> -1.0.0-1
- Feature: first release
