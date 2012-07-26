# Configuration for check_puppet_dashboard_node.pl and dashboard_node_check_wrapper.pl
##################################################################################
#
# The latest version of this plugin can always be obtained from:
#  $HeadURL: http://svn.jasonantman.com/public-nagios/check_linode_transfer.pl $
#  $LastChangedRevision: 10 $
#
##################################################################################

package check_dashboard_config;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(munge_hostname_for_nagios $db_host $db_user $db_pass $db_name $send_nsca_path $nsca_config $nsca_host $nsca_port $svc_desc);

# BEGIN CONFIGURATION
$db_host = ""; # database host
$db_user = ""; # database user
$db_pass = ""; # database password
$db_name = "dashboard"; # database name (schema name)
$send_nsca_path = "/usr/sbin/send_nsca"; # full path to send_nsca
$nsca_config = "/etc/nagios/send_nsca.cfg"; # send_nsca config file
$nsca_host = "icinga.example.com"; # host to send NSCA reports to
$nsca_port = 5667; # port that NSCA is listening on
$svc_desc = "Puppet Agent: Run Status"; # Nagios service description
sub munge_hostname_for_nagios($) {
    my ($orig) = @_;
    my $final = $orig;
    $final =~ s/.example.com$//;
    return $final;
}
# END CONFIGURATION
