##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/projects/Framework/
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary

        include Msf::Auxiliary::Report
	include Msf::Exploit::ORACLE
	
	def initialize(info = {})
		super(update_info(info,
                                'Name'           => 'Simple Oracle Database Enumeration.',
                                'Description'    => %q{
					This module allows for simple Oracle Databse Enumeration of parameters
                                        that might be of importance during a Pentest.
                                },
                                'Author'         => [ 'Carlos Perez <carlos_perez [at] darkoperator [dot] com>' ],
                                'License'        => MSF_LICENSE,
                                'Version'        => '$Revision$',
                                'References'     =>
                                  [
					[ 'URL', 'http://www.darkoperator.com' ],
				]))

	end
        def plsql_query(exec)
                querydata = ""
                begin
                        sploit = connect.prepare(exec)
                        sploit.execute
                rescue DBI::DatabaseError => e
                        raise e.to_s
                        #print_status("\t#{e.to_s}")
                        return
                end

                begin
                        sploit.each do | data |
				querydata << ("#{data.join(",").to_s} \n")
			end
                        sploit.finish
                rescue DBI::DatabaseError => e
                        #print_error("#{e.to_s}")
                        if ( e.to_s =~ /ORA-24374: define not done before fetch or execute and fetch/ )
                                print_status("Done...")
                        else
                                return
                        end
                end
                return querydata
        end

	def run
                begin
                        #Get all values from v$parameter
                        query = 'select name,value from v$parameter'
                        vparm = {}
                        params = plsql_query(query)
                        params.each_line do |l|
                                name,value = l.split(",")
                                vparm["#{name}"] = value
                        end

                end

		begin
                        print_status("Running Oracle Enumeration....")
                        #Version Check
                        query =  'select * from v$version'
			ver = plsql_query(query)
                        print_status("The versions of the Components are:")
                        ver.each_line do |v|
                                print_status("\t#{v.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Component Version: #{v.chomp}")
                        end
                        #Saving Major Release Number for other checks
                        majorrel = ver.scan(/Edition Release (\d*)./)
                        
                        #-------------------------------------------------------
                        #Audit Check
                        print_status("Auditing:")
                        begin
                                if vparm["audit_trail"] == "NONE"
                                        print_status("\tDatabase Auditing is not enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit Trail: Disabled")
                                else
                                        print_status("\tDatabase Auditing is enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit Trail: Enabled")
                                end
           
                                if vparm["audit_sys_operations"] == "FALSE"
                                        print_status("\tAuditing of SYS Operations is not enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit SYS Ops: Disabled")
                                else
                                        print_status("\tAuditing of SYS Operations is enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit SYS Ops: Enabled")
                                end
                                           
                        end
                        #-------------------------------------------------------
                        #Security Settings
                        print_status("Security Settings:")
                        begin
                        
                                if vparm["sql92_security"] == "FALSE"
                                        print_status("\tSQL92 Security restriction on SELECT is not Enabled")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "SQL92: Disabled")
                                else
                                        print_status("\tSQL92 Security restriction on SELECT is Enabled")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "SQL92: Enabled")
                                end
                                
                     
                                #check for encryption of logins on version before 10g
                    
                                if majorrel.join.to_i < 10
                  
                                        if vparm["dblink_encrypt_login"] == "FALSE"
                                                print_status("\tLink Encryption for Logins is not Enabled")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Link Encryption: Disabled")
                                        else
                                                print_status("\tLink Encryption for Logins is Enabled")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Link Encryption: Enabled")
                                        end
                                end
                                
                                print_status("\tUTL Directory Access is set to #{utl.chomp}") if vparm["utl_file_dir"] != " "
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "UTL_DIR: #{ vparm["utl_file_dir"]}") if not  vparm["utl_file_dir"].empty?
                                
                                print_status("\tAudit log is saved at #{vparm["audit_file_dest"]}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit Log Location: #{ vparm["audit_file_dest"]}") if not  vparm["audit_file_dest"].empty?
                                
                        rescue
                                
                        end
                        #-------------------------------------------------------
                        #Password Policy
                        print_status("Password Policy:")
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_LOCK_TIME'
                                AND profile         = 'DEFAULT'
                                |
                                lockout = plsql_query(query)
                                print_status("\tCurrent Account Lockout Time is set to #{lockout.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account Lockout Time: #{lockout.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'FAILED_LOGIN_ATTEMPTS'
                                AND profile         = 'DEFAULT'
                                |
                                failed_logins = plsql_query(query)
                                print_status("\tThe Number of Failed Logins before an account is locked is set to #{failed_logins.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account Fail Logins Permitted: #{failed_logins.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'FAILED_LOGIN_ATTEMPTS'
                                AND profile         = 'DEFAULT'
                                |
                                grace_time = plsql_query(query)
                                print_status("\tThe Password Grace Time is set to #{grace_time.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account Password Grace Time: #{grace_time.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_LIFE_TIME'
                                AND profile         = 'DEFAULT'
                                |
                                passlife_time = plsql_query(query)
                                print_status("\tThe Lifetime of Passwords is set to #{passlife_time.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Life Time: #{passlife_time.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_REUSE_TIME'
                                AND profile         = 'DEFAULT'
                                |
                                passreuse = plsql_query(query)
                                print_status("\tThe Number of Times a Password can be reused is set to #{passreuse.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Reuse Time: #{passreuse.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_REUSE_MAX'
                                AND profile         = 'DEFAULT'
                                |
                                passreusemax = plsql_query(query)
                                print_status("\tThe Maximun Number of Times a Password needs to be changed before it can be reused is set to #{passreusemax.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Maximun Reuse Time: #{passreusemax.chomp}")
                                print_status("\tThe Number of Times a Password can be reused is set to #{passreuse.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_VERIFY_FUNCTION'
                                AND profile         = 'DEFAULT'
                                |
                                passrand = plsql_query(query)
                                if passrand =~ /NULL/
                                        print_status("\tPassword Complexity is not checked")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Complexity is not being checked for new passwords")
                                else
                                        print_status("\tPassword Complexity is being checked")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Complexity is being checked for new passwords")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        #-------------------------------------------------------
                        begin
                                
                                if majorrel.join.to_i < 11
                                       
                                        query = %Q|
                                SELECT name, password 
                                FROM sys.user$
                                where password != 'null' and  type# = 1 and astatus = 0
                                        |
                                        activeacc = plsql_query(query)
                                        print_status("Active Accounts on the System in format Username,Hash are:")
                                        activeacc.each_line do |aa|
                                                print_status("\t#{aa.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Active Account #{aa.chomp}")
                                        end
                                else
                                        query = %Q|
                                        SELECT name, password, spare4
                                        FROM sys.user$
                                        where password != 'null' and  type# = 1 and astatus = 0
                                        |
                                        activeacc = plsql_query(query)
                                        print_status("Active Accounts on the System in format Username,Password,Spare4 are:")
                                        activeacc.each_line do |aa|
                                                print_status("\t#{aa.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Active Account #{aa.chomp}")
                                        end
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                        
                                end
                        end
                        begin
                                if majorrel.join.to_i < 11
                                        query = %Q|
                                SELECT username, password 
                                FROM dba_users
                                WHERE account_status = 'EXPIRED & LOCKED'
                                        |
                                        disabledacc = plsql_query(query)
                                        print_status("Expired or Locked Accounts on the System in format Username,Hash are:")
                                        disabledacc.each_line do |da|
                                                print_status("\t#{da.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Disabled Account #{da.chomp}")
                                        end
                                else
                                        query = %Q|
                                SELECT name, password, spare4
                                        FROM sys.user$
                                        where password != 'null' and  type# = 1 and astatus = 8 or astatus = 9
                                        |
                                        disabledacc = plsql_query(query)
                                        print_status("Expired or Locked Accounts on the System in format Username,Password,Spare4 are:")
                                        disabledacc.each_line do |da|
                                                print_status("\t#{da.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Disabled Account #{da.chomp}")
                                        end
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        begin
                                query = %Q|
                                SELECT grantee
                                FROM dba_role_privs
                                WHERE granted_role = 'DBA'
                                |
                                dbaacc = plsql_query(query)
                                print_status("Accounts with DBA Privilege  in format Username,Hash on the System are:")
                                dbaacc.each_line do |dba|
                                        print_status("\t#{dba.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with DBA Priv  #{dba.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        begin
                                query = %Q|
                                SELECT grantee
                                FROM dba_sys_privs
                                WHERE privilege = 'ALTER SYSTEM'
                                |
                                altersys = plsql_query(query)
                                print_status("Accounts with Alter System Privilege on the System are:")
                                altersys.each_line do |as|
                                        print_status("\t#{as.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with ALTER SYSTEM Priv  #{as.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        begin
                                query = %Q|
                                SELECT grantee
                                FROM dba_sys_privs
                                WHERE privilege = 'JAVA ADMIN'
                                |
                                javaacc = plsql_query(query)
                                print_status("Accounts with JAVA ADMIN Privilege on the System are:")
                                javaacc.each_line do |j|
                                        print_status("\t#{j.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with JAVA ADMIN Priv  #{j.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end

                        begin
                                query = %Q|
                                select grantee
                                from dba_sys_privs
                                where privilege = 'CREATE LIBRARY'
                                or privilege = 'CREATE ANY'
                                |
                                libpriv = plsql_query(query)
                                print_status("Accounts that have CREATE LIBRARY Privilege on the System are:")
                                libpriv.each_line do |lp|
                                        print_status("\t#{lp.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with CREATE LIBRARY Priv  #{lp.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        #Default Password Check
                        begin
                                print_status("Default password check:")
                                if majorrel.join.to_i == 11
                                        query = %Q|
                                        SELECT * FROM dba_users_with_defpwd
                                        |
                                        defpwd = plsql_query(query)
                                        defpwd.each do |dp|
                                                print_status("\tThe account #{dp.chomp} has a default password.")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with Default Password #{dp.chomp}")
                                        end

                                else
                                        query = %Q|
                                SELECT name, password
                                FROM sys.user$
                                where password != 'null' and  type# = 1
                                        |
                                        ordfltpss =%W{
BRIO_ADMIN,BRIO_ADMIN,EB50644BE27DF70B
BRUGERNAVN,ADGANGSKODE,2F11631B6B4E0B6F
BRUKERNAVN,PASSWORD,652C49CDF955F83A
BSC,BSC,EC481FD7DCE6366A
BUG_REPORTS,BUG_REPORTS,E9473A88A4DD31F2
CALVIN,HOBBES,34200F94830271A3
CATALOG,CATALOG,397129246919E8DA
CCT,CCT,C6AF8FCA0B51B32F
CDEMO82,CDEMO82,7299A5E2A5A05820
CDEMO82,CDEMO83,67B891F114BE3AEB
CDEMOCOR,CDEMOCOR,3A34F0B26B951F3F
CDEMORID,CDEMORID,E39CEFE64B73B308
CDEMOUCB,CDEMOUCB,CEAE780F25D556F8
CDOUGLAS,CDOUGLAS,C35109FE764ED61E
CE,CE,E7FDFE26A524FE39
CENTRA,CENTRA,63BF5FFE5E3EA16D
CENTRAL,CENTRAL,A98B26E2F65CA4D3
CIDS,CIDS,AA71234EF06CE6B3
CIS,CIS,7653EBAF048F0A10
CIS,ZWERG,AA2602921607EE84
CISINFO,CISINFO,3AA26FC267C5F577
CISINFO,ZWERG,BEA52A368C31B86F
CLARK,CLOTH,7AAFE7D01511D73F
CN,CN,73F284637A54777D
COMPANY,COMPANY,402B659C15EAF6CB
COMPIERE,COMPIERE,E3D0DCF4B4DBE626
CQSCHEMAUSER,PASSWORD,04071E7EDEB2F5CC
CQUSERDBUSER,PASSWORD,0273F484CD3F44B7
CRP,CRP,F165BDE5462AD557
CS,CS,DB78866145D4E1C3
CSC,CSC,EDECA9762A8C79CD
CSD,CSD,144441CEBAFC91CF
CSE,CSE,D8CC61E8F42537DA
CSF,CSF,684E28B3C899D42C
CSI,CSI,71C2B12C28B79294
CSL,CSL,C4D7FE062EFB85AB
CSMIG,CSMIG,09B4BB013FBD0D65
CSP,CSP,5746C5E077719DB4
CSR,CSR,0E0F7C1B1FE3FA32
CSS,CSS,3C6B8C73DDC6B04F
CTXDEMO,CTXDEMO,CB6B5E9D9672FE89
CTXSYS,CHANGE_ON_INSTALL,71E687F036AD56E5
CTXSYS,CTXSYS,24ABAB8B06281B4C
CUA,CUA,CB7B2E6FFDD7976F
CUE,CUE,A219FE4CA25023AA
CUF,CUF,82959A9BD2D51297
CUG,CUG,21FBCADAEAFCC489
CUI,CUI,AD7862E01FA80912
CUN,CUN,41C2D31F3C85A79D
CUP,CUP,C03082CD3B13EC42
CUS,CUS,00A12CC6EBF8EDB8
CZ,CZ,9B667E9C5A0D21A6
DATA_SCHEMA,LASKJDF098KSDAF09,5ECB30FD1A71CC54
DBI,MUMBLEFRATZ,D8FF6ECEF4C50809
HR,CHANGE_ON_INSTALL,6399F3B38EDF3288
HR,HR,4C6D73C3E8B0F0DA
HRI,HRI,49A3A09B8FC291D0
HVST,HVST,5787B0D15766ADFD
HXC,HXC,4CEA0BF02214DA55
HXT,HXT,169018EB8E2C4A77
IBA,IBA,0BD475D5BF449C63
IBE,IBE,9D41D2B3DD095227
IBP,IBP,840267B7BD30C82E
IBU,IBU,0AD9ABABC74B3057
IBY,IBY,F483A48F6A8C51EC
ICDBOWN,ICDBOWN,76B8D54A74465BB4
ICX,ICX,7766E887AF4DCC46
IDEMO_USER,IDEMO_USER,739F5BC33AC03043
IEB,IEB,A695699F0F71C300
IEC,IEC,CA39F929AF0A2DEC
IEM,IEM,37EF7B2DD17279B5
IEO,IEO,E93196E9196653F1
IES,IES,30802533ADACFE14
IEU,IEU,5D0E790B9E882230
IEX,IEX,6CC978F56D21258D
IFSSYS,IFSSYS,1DF0D45B58E72097
IGC,IGC,D33CEB8277F25346
IGF,IGF,1740079EFF46AB81
IGI,IGI,8C69D50E9D92B9D0
IGS,IGS,DAF602231281B5AC
IGW,IGW,B39565F4E3CF744B
IMAGEUSER,IMAGEUSER,E079BF5E433F0B89
IMC,IMC,C7D0B9CDE0B42C73
IMEDIA,IMEDIA,8FB1DC9A6F8CE827
IMT,IMT,E4AAF998653C9A72
#INTERNAL,ORACLE,87DADF57B623B777
#INTERNAL,SYS_STNT,38379FC3621F7DA2
INTERNAL,ORACLE,AB27B53EDC5FEF41
INTERNAL,SYS_STNT,E0BF7F3DDE682D3B
INV,INV,ACEAB015589CF4BC
IPA,IPA,EB265A08759A15B4
IPD,IPD,066A2E3072C1F2F3
IPLANET,IPLANET,7404A12072F4E5E8
ISC,ISC,373F527DC0CFAE98
ITG,ITG,D90F98746B68E6CA
JA,JA,9AC2B58153C23F3D
JAKE,PASSWO4,1CE0B71B4A34904B
JE,JE,FBB3209FD6280E69
JG,JG,37A99698752A1CF1
JILL,PASSWO2,D89D6F9EB78FC841
JL,JL,489B61E488094A8D
JMUSER,JMUSER,063BA85BF749DF8E
JOHN,JOHN,29ED3FDC733DC86D
JONES,STEEL,B9E99443032F059D
JTF,JTF,5C5F6FC2EBB94124
JTM,JTM,6D79A2259D5B4B5A
JTS,JTS,4087EE6EB7F9CD7C
JWARD,AIROPLANE,CF9CB787BD98DA7F
KWALKER,KWALKER,AD0D93891AEB26D2
L2LDEMO,L2LDEMO,0A6B2DF907484CEE
LBACSYS,LBACSYS,AC9700FD3F1410EB
LIBRARIAN,SHELVES,11E0654A7068559C
MANPROD,MANPROD,F0EB74546E22E94D
MARK,PASSWO3,F7101600ACABCD74
MASCARM,MANAGER,4EA68D0DDE8AAC6B
MASTER,PASSWORD,9C4F452058285A74
MDDATA,MDDATA,DF02A496267DEE66
MDDEMO,MDDEMO,46DFFB4D08C33739
MDDEMO_CLERK,CLERK,564F871D61369A39
MDDEMO_CLERK,MGR,E5288E225588D11F
MDDEMO_MGR,MDDEMO_MGR,2E175141BEE66FF6
MDSYS,MDSYS,72979A94BAD2AF80
ME,ME,E5436F7169B29E4D
MFG,MFG,FC1B0DD35E790847
MGR,MGR,9D1F407F3A05BDD9
MGWUSER,MGWUSER,EA514DD74D7DE14C
MIGRATE,MIGRATE,5A88CE52084E9700
MILLER,MILLER,D0EFCD03C95DF106
MMO2,MMO2,AE128772645F6709
MMO2,MMO3,A0E2085176E05C85
MODTEST,YES,BBFF58334CDEF86D
MOREAU,MOREAU,CF5A081E7585936B
MRP,MRP,B45D4DF02D4E0C85
MSC,MSC,89A8C104725367B2
MSD,MSD,6A29482069E23675
MSO,MSO,3BAA3289DB35813C
MSR,MSR,C9D53D00FE77D813
MTS_USER,MTS_PASSWORD,E462DB4671A51CD4
MTSSYS,MTSSYS,6465913FF5FF1831
MWA,MWA,1E2F06BE2A1D41A6
MXAGENT,MXAGENT,C5F0512A64EB0E7F
NAMES,NAMES,9B95D28A979CC5C4
NEOTIX_SYS,NEOTIX_SYS,05BFA7FF86D6EB32
NNEUL,NNEULPASS,4782D68D42792139
NOM_UTILISATEUR,MOT_DE_PASSE,FD621020564A4978
NOMEUTENTE,PASSWORD,8A43574EFB1C71C7
NOME_UTILIZADOR,SENHA,71452E4797DF917B
NUME_UTILIZATOR,PAROL,73A3AC32826558AE
OAS_PUBLIC,OAS_PUBLIC,A8116DB6E84FA95D
OCITEST,OCITEST,C09011CB0205B347
OCM_DB_ADMIN,OCM_DB_ADMIN,2C3A5DEF1EE57E92
ODM,ODM,C252E8FA117AF049
ODM_MTR,MTRPW,A7A32CD03D3CE8D5
ODS,ODS,89804494ADFC71BC
ODS_SERVER,ODS_SERVER,C6E799A949471F57
ODSCOMMON,ODSCOMMON,59BBED977430C1A8
OE,CHANGE_ON_INSTALL,9C30855E7E0CB02D
OE,OE,D1A2DFC623FDA40A
OEMADM,OEMADM,9DCE98CCF541AAE6
OEMREP,OEMREP,7BB2F629772BF2E5
OKB,OKB,A01A5F0698FC9E31
OKC,OKC,31C1DDF4D5D63FE6
OKE,OKE,B7C1BB95646C16FE
OKI,OKI,991C817E5FD0F35A
OKO,OKO,6E204632EC7CA65D
OKR,OKR,BB0E28666845FCDC
OKS,OKS,C2B4C76AB8257DF5
OKX,OKX,F9FDEB0DE52F5D6B
OLAPDBA,OLAPDBA,1AF71599EDACFB00
OLAPSVR,INSTANCE,AF52CFD036E8F425
OLAPSVR,OLAPSVR,3B3F6DB781927D0F
OLAPSYS,MANAGER,3FB8EF9DB538647C
OLAPSYS,OLAPSYS,C1510E7AC8F0D90D
OMWB_EMULATION,ORACLE,54A85D2A0AB8D865
ONT,ONT,9E3C81574654100A
OO,OO,2AB9032E4483FAFC
OPENSPIRIT,OPENSPIRIT,D664AAB21CE86FD2
OPI,OPI,1BF23812A0AEEDA0
ORACACHE,ORACACHE,5A4EEC421DE68DDD
ORACLE,ORACLE,38E38619A12E0257
ORADBA,ORADBAPASS,C37E732953A8ABDB
ORAPROBE,ORAPROBE,2E3EA470A4CA2D94
ORAREGSYS,ORAREGSYS,28D778112C63CB15
ORASSO,ORASSO,F3701A008AA578CF
ORASSO_DS,ORASSO_DS,17DC8E02BC75C141
ORASSO_PA,ORASSO_PA,133F8D161296CB8F
ORASSO_PS,ORASSO_PS,63BB534256053305
ORASSO_PUBLIC,ORASSO_PUBLIC,C6EED68A8F75F5D3
ORASTAT,ORASTAT,6102BAE530DD4B95
ORCLADMIN,WELCOME,7C0BE475D580FBA2
ORDCOMMON,ORDCOMMON,9B616F5489F90AD7
DBSNMP,DBSNMP,E066D214D5421CCC
DBVISION,DBVISION,F74F7EF36A124931
DDIC,199220706,4F9FFB093F909574
DEMO,DEMO,4646116A123897CF
DEMO8,DEMO8,0E7260738FDFD678
DEMO9,DEMO9,EE02531A80D998CA
DES,DES,ABFEC5AC2274E54D
DES2K,DES2K,611E7A73EC4B425A
DEV2000_DEMOS,DEV2000_DEMOS,18A0C8BD6B13BEE2
DIANE,PASSWO1,46DC27700F2ADE28
DIP,DIP,CE4A36B8E06CA59C
DISCOVERER_ADMIN,DISCOVERER_ADMIN,5C1AED4D1AADAA4C
DMSYS,DMSYS,BFBA5A553FD9E28A
DPF,DPFPASS,E53F7C782FAA6898
DSGATEWAY,DSGATEWAY,6869F3CFD027983A
DSSYS,DSSYS,E3B6E6006B3A99E0
DTSP,DTSP,5A40D4065B3673D2
EAA,EAA,A410B2C5A0958CDF
EAM,EAM,CE8234D92FCFB563
EARLYWATCH,SUPPORT,8AA1C62E08C76445
EAST,EAST,C5D5C455A1DE5F4D
EC,EC,6A066C462B62DD46
ECX,ECX,0A30645183812087
EJB,EJB,69CB07E2162C6C93
EJSADMIN,EJSADMIN,4C59B97125B6641A
EJSADMIN,EJSADMIN_PASSWORD,313F9DFD92922CD2
EMP,EMP,B40C23C6E2B4EA3D
ENG,ENG,4553A3B443FB3207
ENI,ENI,05A92C0958AFBCBC
ESTOREUSER,ESTORE,51063C47AC2628D4
EVENT,EVENT,7CA0A42DA768F96D
EVM,EVM,137CEDC20DE69F71
EXAMPLE,EXAMPLE,637417B1DC47C2E5
EXFSYS,EXFSYS,66F4EF5650C20355
EXTDEMO,EXTDEMO,BAEF9D34973EE4EC
EXTDEMO2,EXTDEMO2,6A10DD2DB23880CB
FA,FA,21A837D0AED8F8E5
FEM,FEM,BD63D79ADF5262E7
FII,FII,CF39DE29C08F71B9
FINANCE,FINANCE,6CBBF17292A1B9AA
FINPROD,FINPROD,8E2713F53A3D69D5
FLM,FLM,CEE2C4B59E7567A3
FND,FND,0C0832F8B6897321
FOO,BAR,707156934A6318D4
FPT,FPT,73E3EC9C0D1FAECF
FRM,FRM,9A2A7E2EBE6E4F71
FROSTY,SNOWMAN,2ED539F71B4AA697
FTE,FTE,2FB4D2C9BAE2CCCA
FV,FV,907D70C0891A85B1
GL,GL,CD6E99DACE4EA3A6
GMA,GMA,DC7948E807DFE242
GMD,GMD,E269165256F22F01
GME,GME,B2F0E221F45A228F
GMF,GMF,A07F1956E3E468E1
GMI,GMI,82542940B0CF9C16
GML,GML,5F1869AD455BBA73
GMP,GMP,450793ACFCC7B58E
GMS,GMS,E654261035504804
GPFD,GPFD,BA787E988F8BC424
GPLD,GPLD,9D561E4D6585824B
GR,GR,F5AB0AA3197AEE42
HADES,HADES,2485287AC1DB6756
HCPARK,HCPARK,3DE1EBA32154C56B
HLW,HLW,855296220C095810
ABM,ABM,D0F2982F121C7840
ADAMS,WOOD,72CDEF4A3483F60D
ADLDEMO,ADLDEMO,147215F51929A6E8
ADMIN,JETSPEED,CAC22318F162D597
ADMIN,WELCOME,B8B15AC9A946886A
ADMINISTRATOR,ADMIN,F9ED601D936158BD
ADMINISTRATOR,ADMINISTRATOR,1848F0A31D1C5C62
AHL,AHL,7910AE63C9F7EEEE
AHM,AHM,33C2E27CF5E401A4
AK,AK,8FCB78BBA8A59515
ALHRO,XXX,049B2397FB1A419E
ALHRW,XXX,B064872E7F344CAE
ALR,ALR,BE89B24F9F8231A9
AMS,AMS,BD821F59270E5F34
AMV,AMV,38BC87EB334A1AC4
ANDY,SWORDFISH,B8527562E504BC3F
ANONYMOUS,ANONYMOUS,FE0E8CE7C92504E9
AP,AP,EED09A552944B6AD
APPLMGR,APPLMGR,CB562C240E871070
APPLSYS,APPLSYS,FE84888987A6BF5A
APPLSYS,APPS,E153FFF4DAE6C9F7
APPLSYS,FND,0F886772980B8C79
APPLSYSPUB,APPLSYSPUB,D5DB40BB03EA1270
APPLSYSPUB,PUB,D2E3EF40EE87221E
APPLSYSPUB,FNDPUB,78194639B5C3DF9F
APPLYSYSPUB,FNDPUB,78194639B5C3DF9F
APPLYSYSPUB,PUB,A5E09E84EC486FC9
APPS,APPS,D728438E8A5925E0
APPS_MRC,APPS,2FFDCBB4FD11D9DC
APPUSER,APPPASSWORD,7E2C3C2D4BF4071B
AQ,AQ,2B0C31040A1CFB48
AQDEMO,AQDEMO,5140E342712061DD
AQJAVA,AQJAVA,8765D2543274B42E
AQUSER,AQUSER,4CF13BDAC1D7511C
AR,AR,BBBFE175688DED7E
ASF,ASF,B6FD427D08619EEE
ASG,ASG,1EF8D8BD87CF16BE
ASL,ASL,03B20D2C323D0BFE
ASO,ASO,F712D80109E3C9D8
ASP,ASP,CF95D2C6C85FF513
AST,AST,F13FF949563EAB3C
ATM,SAMPLEATM,7B83A0860CF3CB71
AUDIOUSER,AUDIOUSER,CB4F2CEC5A352488
AURORA$JIS$UTILITY$,INVALID,E1BAE6D95AA95F1E
AX,AX,0A8303530E86FCDD
AZ,AZ,AAA18B5D51B0D5AC
BC4J,BC4J,EAA333E83BF2810D
BEN,BEN,1.80E+308
BIC,BIC,E84CC95CBBAC1B67
BIL,BIL,BF24BCE2409BE1F7
BIM,BIM,6026F9A8A54B9468
BIS,BIS,7E9901882E5F3565
BIV,BIV,2564B34BE50C2524
BIX,BIX,3DD36935EAEDE2E3
BLAKE,PAPER,9435F2E60569158E
BLEWIS,BLEWIS,C9B597D7361EE067
BOM,BOM,56DB3E89EAE5788E
SYSMAN,SYSMAN,447B729161192C24
SYSTEM,CHANGE_ON_INSTALL,8BF0DA8E551DE1B9
SYSTEM,D_SYSPW,1B9F1F9A5CB9EB31
SYSTEM,MANAGER,D4DF7931AB130E37
SYSTEM,ORACLE,2D594E86F93B17A1
SYSTEM,SYSTEMPASS,4861C2264FB17936
SYSTEM,SYSTEM,970BAA5B81930A40
SYSTEM,MANAG3R,135176FFB5BA07C9
SYSTEM,ORACL3,E4519FCD3A565446
SYSTEM,0RACLE,66A490AEAA61FF72
SYSTEM,0RACL3,10B0C2DA37E11872
SYSTEM,ORACLE8,D5DD57A09A63AA38
SYSTEM,ORACLE9,69C27FA786BA774C
SYSTEM,ORACLE9I,86FDB286770CD4B9
SYSTEM,0RACLE9I,B171042374D7E6A2
SYSTEM,0RACL39I,D7C18B3B3F2A4D4B
TAHITI,TAHITI,F339612C73D27861
TALBOT,MT6CH5,905475E949CF2703
TDOS_ICSAP,TDOS_ICSAP,7C0900F751723768
TEC,TECTEC,9699CFD34358A7A7
TEST,PASSWD,26ED9DD4450DD33C
TEST,TEST,7A0F2B316C212D67
TEST_USER,TEST_USER,C0A0F776EBBBB7FB
TESTPILOT,TESTPILOT,DE5B73C964C7B67D
THINSAMPLE,THINSAMPLEPW,5DCD6E2E26D33A6E
TIBCO,TIBCO,ED4CDE954630FA82
TIP37,TIP37,B516D9A33679F56B
TRACESVR,TRACE,F9DA8977092B7B81
TRAVEL,TRAVEL,97FD0AE6DFF0F5FE
TSDEV,TSDEV,29268859446F5A8C
TSUSER,TSUSER,90C4F894E2972F08
TURBINE,TURBINE,76F373437F33F347
ULTIMATE,ULTIMATE,4C3F880EFA364016
UM_ADMIN,UM_ADMIN,F4F306B7AEB5B6FC
UM_CLIENT,UM_CLIENT,82E7FF841BFEAB6C
USER,USER,74085BE8A9CF16B4
USER_NAME,PASSWORD,96AE343CA71895DA
USER0,USER0,8A0760E2710AB0B4
USER1,USER1,BBE7786A584F9103
USER2,USER2,1718E5DBB8F89784
USER3,USER3,94152F9F5B35B103
USER4,USER4,2907B1BFA9DA5091
USER5,USER5,6E97FCEA92BAA4CB
USER6,USER6,F73E1A76B1E57F3D
USER7,USER7,3E9C94488C1A3908
USER8,USER8,D148049C2780B869
USER9,USER9,0487AFEE55ECEE66
UTILITY,UTILITY,81F2423D6811246D
USUARIO,CLAVE,1AB4E5FD2217F7AA
UTLBSTATU,UTLESTAT,C42D1FA3231AB025
VEA,VEA,D38D161C22345902
VEH,VEH,72A90A786AAE2914
VERTEX_LOGIN,VERTEX_LOGIN,DEF637F1D23C0C59
VIDEOUSER,VIDEOUSER,29ECA1F239B0F7DF
VIF_DEVELOPER,VIF_DEV_PWD,9A7DCB0C1D84C488
VIRUSER,VIRUSER,404B03707BF5CEA3
VPD_ADMIN,AKF7D98S2,571A7090023BCD04
VRR1,VRR1,811C49394C921D66
VRR1,VRR2,3D703795F61E3A9A
WEBCAL01,WEBCAL01,C69573E9DEC14D50
WEBDB,WEBDB,D4C4DCDD41B05A5D
WEBREAD,WEBREAD,F8841A7B16302DE6
WEBSYS,MANAGER,A97282CE3D94E29E
WEBUSER,YOUR_PASS,FD0C7DB4C69FA642
WEST,WEST,DD58348364219102
WFADMIN,WFADMIN,C909E4F104002876
WH,WH,91792EFFCB2464F9
WIP,WIP,D326D25AE0A0355C
WKADMIN,WKADMIN,888203D36F64C5F6
WKPROXY,WKPROXY,AA3CB2A4D9188DDB
WKPROXY,CHANGE_ON_INSTALL,B97545C4DD2ABE54
WKSYS,CHANGE_ON_INSTALL,69ED49EE1851900D
WKSYS,WKSYS,545E13456B7DDEA0
WKUSER,WKUSER,8B104568E259B370
WK_TEST,WK_TEST,29802572EB547DBF
WMS,WMS,D7837F182995E381
WMSYS,WMSYS,7C9BA362F8314299
WOB,WOB,D27FA6297C0313F4
WPS,WPS,50D22B9D18547CF7
WSH,WSH,D4D76D217B02BD7A
WSM,WSM,750F2B109F49CC13
WWW,WWW,6DE993A60BC8DBBF
WWWUSER,WWWUSER,F239A50072154BAC
XADEMO,XADEMO,ADBC95D8DCC69E66
XDB,CHANGE_ON_INSTALL,88D8364765FCE6AF
XDP,XDP,F05E53C662835FA2
XLA,XLA,2A8ED59E27D86D41
XNC,XNC,BD8EA41168F6C664
XNI,XNI,F55561567EF71890
XNM,XNM,92776EA17B8B5555
XNP,XNP,3D1FB783F96D1F5E
XNS,XNS,FABA49C38150455E
XPRT,XPRT,0D5C9EFC2DFE52BA
XTR,XTR,A43EE9629FA90CAE
MDDEMO_MGR,MGR,B41BCD9D3737F5C4
SYSTEM,D_SYSTPW,4438308EE0CAFB7F
SYSTEM,ORACLE8I,FAAD7ADAF48B5F45
SYSTEM,0RACLE8,685657E9DC29E185
SYSTEM,0RACLE9,49B70B505DF0247F
SYSTEM,0RACLE8I,B49C4279EBD8D1A8
SYSTEM,0RACL38,604101D3AACE7E88
SYSTEM,0RACL39,02AB2DB93C952A8F
SYSTEM,0RACL38I,203CD8CF183E716C
SYS,0RACLE8,1FA22316B703EBDD
SYS,0RACLE9,12CFB5AE1D087BA3
SYS,0RACLE8I,380E3D3AD5CE32D4
SYS,0RACL38,2563EFAAE44E785A
SYS,0RACL39,E7686462E8CD2F5E
SYS,0RACL38I,691C5E7E424B821A
ORDPLUGINS,ORDPLUGINS,88A2B2C183431F00
ORDSYS,ORDSYS,7EFA02EC7EA6B86F
OSE$HTTP$ADMIN,Invalid password,INVALID_ENCRYPTED_PASSWORD
OSE$HTTP$ADMIN,INVALID,05327CD9F6114E21
OSM,OSM,106AE118841A5D8C
OSP22,OSP22,C04057049DF974C2
OTA,OTA,F5E498AC7009A217
OUTLN,OUTLN,4A3BA55E08595C81
OWA,OWA,CA5D67CD878AFC49
OWA_PUBLIC,OWA_PUBLIC,0D9EC1D1F2A37657
OWF_MGR,OWF_MGR,3CBED37697EB01D1
OWNER,OWNER,5C3546B4F9165300
OZF,OZF,970B962D942D0C75
OZP,OZP,B650B1BB35E86863
OZS,OZS,0DABFF67E0D33623
PA,PA,8CE2703752DB36D8
PANAMA,PANAMA,3E7B4116043BEAFF
PATROL,PATROL,0478B8F047DECC65
PAUL,PAUL,35EC0362643ADD3F
PERFSTAT,PERFSTAT,AC98877DE1297365
PERSTAT,PERSTAT,A68F56FBBCDC04AB
PJM,PJM,021B05DBB892D11F
PLANNING,PLANNING,71B5C2271B7CFF18
PLEX,PLEX,99355BF0E53FF635
PLSQL,SUPERSECRET,C4522E109BCF69D0
PM,CHANGE_ON_INSTALL,72E382A52E89575A
PM,PM,C7A235E6D2AF6018
PMI,PMI,A7F7978B21A6F65E
PN,PN,D40D0FEF9C8DC624
PO,PO,355CBEC355C10FEF
PO7,PO7,6B870AF28F711204
PO8,PO8,7E15FBACA7CDEBEC
POA,POA,2AB40F104D8517A0
POM,POM,123CF56E05D4EF3C
PORTAL_DEMO,PORTAL_DEMO,A0A3A6A577A931A3
PORTAL_SSO_PS,PORTAL_SSO_PS,D1FB757B6E3D8E2F
PORTAL30,PORTAL30,969F9C3839672C6D
PORTAL30,PORTAL31,D373ABE86992BE68
PORTAL30_ADMIN,PORTAL30_ADMIN,7AF870D89CABF1C7
PORTAL30_DEMO,PORTAL30_DEMO,CFD1302A7F832068
PORTAL30_PS,PORTAL30_PS,333B8121593F96FB
PORTAL30_PUBLIC,PORTAL30_PUBLIC,42068201613CA6E2
PORTAL30_SSO,PORTAL30_SSO,882B80B587FCDBC8
PORTAL30_SSO_ADMIN,PORTAL30_SSO_ADMIN,BDE248D4CCCD015D
PORTAL30_SSO_PS,PORTAL30_SSO_PS,F2C3DC8003BC90F8
PORTAL30_SSO_PUBLIC,PORTAL30_SSO_PUBLIC,98741BDA2AC7FFB2
POS,POS,6F6675F272217CF7
POWERCARTUSER,POWERCARTUSER,2C5ECE3BEC35CE69
PRIMARY,PRIMARY,70C3248DFFB90152
PSA,PSA,FF4B266F9E61F911
PSB,PSB,28EE1E024FC55E66
PSP,PSP,4FE07360D435E2F0
PUBSUB,PUBSUB,80294AE45A46E77B
PUBSUB1,PUBSUB1,D6DF5BBC8B64933E
PV,PV,76224BCC80895D3D
QA,QA,C7AEAA2D59EB1EAE
QDBA,QDBA,AE62CB8167819595
QP,QP,10A40A72991DCA15
QS,CHANGE_ON_INSTALL,8B09C6075BDF2DC4
QS,QS,4603BCD2744BDE4F
QS_ADM,CHANGE_ON_INSTALL,991CDDAD5C5C32CA
QS_ADM,QS_ADM,3990FB418162F2A0
QS_CB,CHANGE_ON_INSTALL,CF9CFACF5AE24964
QS_CB,QS_CB,870C36D8E6CD7CF5
QS_CBADM,CHANGE_ON_INSTALL,7C632AFB71F8D305
QS_CBADM,QS_CBADM,20E788F9D4F1D92C
QS_CS,CHANGE_ON_INSTALL,91A00922D8C0F146
QS_CS,QS_CS,2CA6D0FC25128CF3
QS_ES,CHANGE_ON_INSTALL,E6A6FA4BB042E3C2
QS_ES,QS_ES,9A5F2D9F5D1A9EF4
QS_OS,CHANGE_ON_INSTALL,FF09F3EB14AE5C26
QS_OS,QS_OS,0EF5997DC2638A61
QS_WS,CHANGE_ON_INSTALL,24ACF617DD7D8F2F
QS_WS,QS_WS,0447F2F756B4F460
RE,RE,933B9A9475E882A6
REP_MANAGER,DEMO,2D4B13A8416073A1
REP_OWNER,DEMO,88D8F06915B1FE30
REP_OWNER,REP_OWNER,BD99EC2DD84E3B5C
REP_USER,DEMO,57F2A93832685ADB
REPADMIN,REPADMIN,915C93F34954F5F8
REPORTS_USER,OEM_TEMP,635074B4416CD3AC
REPORTS,REPORTS,0D9D14FE6653CF69
RG,RG,0FAA06DA0F42F21F
RHX,RHX,FFDF6A0C8C96E676
RLA,RLA,C1959B03F36C9BB2
RLM,RLM,4B16ACDA351B557D
RMAIL,RMAIL,DA4435BBF8CAE54C
RMAN,RMAN,E7B5D92911C831E1
RRS,RRS,5CA8F5380C959CA9
SAMPLE,SAMPLE,E74B15A3F7A19CA8
SAP,SAPR3,BEAA1036A464F9F0
SAP,6071992,B1344DC1B5F3D903
SAPR3,SAP,58872B4319A76363
SCOTT,TIGER,F894844C34402B67
SCOTT,TIGGER,7AA1A84E31ED7771
SDOS_ICSAP,SDOS_ICSAP,C789210ACC24DA16
SECDEMO,SECDEMO,009BBE8142502E10
SERVICECONSUMER1,SERVICECONSUMER1,183AC2094A6BD59F
SH,CHANGE_ON_INSTALL,9793B3777CD3BD1A
SH,SH,54B253CBBAAA8C48
SITEMINDER,SITEMINDER,061354246A45BBAB
SI_INFORMTN_SCHEMA,SI_INFORMTN_SCHEMA,84B8CBCA4D477FA3
SLIDE,SLIDEPW,FDFE8B904875643D
SPIERSON,SPIERSON,4A0A55000357BB3E
SSP,SSP,87470D6CE203FB4D
STARTER,STARTER,6658C384B8D63B0A
STRAT_USER,STRAT_PASSWD,AEBEDBB4EFB5225B
SWPRO,SWPRO,4CB05AA42D8E3A47
SWUSER,SWUSER,783E58C29D2FC7E1
SYMPA,SYMPA,E7683741B91AF226
SYS,CHANGE_ON_INSTALL,D4C5016086B2DC6A
SYS,D_SYSPW,43BE121A2A135FF3
SYS,MANAGER,5638228DAF52805F
SYS,ORACLE,8A8F025737A9097A
SYS,SYS,4DE42795E66117AE
SYS,SYSPASS,66BC3FF56063CE97
SYS,MANAG3R,57D7CFA12BB5BABF
SYS,ORACL3,A9A57E819B32A03D
SYS,0RACLE,2905ECA56A830226
SYS,0RACL3,64074AF827F4B74A
SYS,ORACLE8,41B328CA13F70713
SYS,ORACLE9,0B4409DDD5688913
SYS,ORACLE8I,6CFF570939041278
SYS,ORACLE9I,3522F32DD32A9706
SYS,0RACLE9I,BE29E31B2B0EDA33
SYS,0RACL39I,5AC333703DE0DBD4
SYSADM,SYSADM,BA3E855E93B5B9B0
SYSADMIN,SYSADMIN,DC86E8DEAA619C1A
SYSMAN,OEM_TEMP,639C32A115D2CA57
                                        }



                                        returnedstring = plsql_query(query)
                                        accts = {}
                                        returnedstring.each_line do |record|
                                                user,pass = record.split(",")
                                                accts["#{pass.chomp.strip}"] = "#{user}"
                                        end
                                        ordfltpss.each do |l|
                                                accrcrd =  l.split(",")
                                                if accts.has_key?(accrcrd[2])
                                                        print_status("\tDefault pass for account #{accrcrd[0]} is #{accrcrd[1]} ")
                                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with Default Password #{accrcrd[0]} is #{accrcrd[1]}")
                                                end
                                        end

                                end
                        end
                        
                rescue => e
                        print_error(e)
                        return
                end
        end

end
