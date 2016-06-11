Summary:	High Performance MySQL Tuning Script
Name:		mysqltuner
Version:	%VERSION%
Release:	1
License:	GPL v3+
Group:		Applications
Source0:	https://github.com/build/MySQLTuner-perl/build/%{name}-%{version}.tgz
URL:		https://github.com/major/MySQLTuner-perl
Requires:	mysql
BuildArch:	noarch
BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
MySQLTuner is a high-performance MySQL tuning script written in Perl
that will provide you with a snapshot of a MySQL server's health.
Based on the statistics gathered, specific recommendations will be
provided that will increase a MySQL server's efficiency and
performance. The script gives you automated MySQL tuning that is on
the level of what you would receive from a MySQL DBA.

This script has been derived from many of the ideas in Matthew
Montgomery's MySQL tuning primer script.

%prep
%setup -q

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT%{_bindir}
install -d $RPM_BUILD_ROOT%{_datarootdir}
install -d $RPM_BUILD_ROOT/%{_mandir}/man1
install -p %{name}.pl $RPM_BUILD_ROOT%{_bindir}/%{name}
install -d $RPM_BUILD_ROOT%{_datarootdir}/%{name}
install -p LICENSE $RPM_BUILD_ROOT%{_datarootdir}/%{name}
install -p basic_passwords.txt $RPM_BUILD_ROOT%{_datarootdir}/%{name}
install -p vulnerabilities.csv $RPM_BUILD_ROOT%{_datarootdir}/%{name}
install -p %{name}.1.gz $RPM_BUILD_ROOT/%{_mandir}/man1

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%doc %{_datarootdir}/%{name}
%attr(755,root,root) %{_bindir}/%{name}
%{_mandir}/man1/*

%changelog
* Thu Apr 14 2016 Jean-Marie RENOUARD <jmrenouard@gmail.com> %VERSION%-1
- Initial RPM release

