/*
 * This file is part of Haguichi, a graphical frontend for Hamachi.
 * Copyright (C) 2007-2015 Stephen Brandt <stephen@stephenbrandt.com>
 *
 * Haguichi is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 */

public class Hamachi : Object
{
    public  static string data_path;
    public  static string version;
    public  static string ip_version;
    public  static string last_info;
    private static string service;
    
    public static void init ()
    {
        data_path  = "/var/lib/logmein-hamachi";
        ip_version = "IPv4";
        
        get_info();
        determine_version();
        determine_service();
    }
    
    public static void determine_version ()
    {
        version = "";
        
        if (Haguichi.demo_mode)
        {
            version = "2.1.0.139";
            return;
        }
        
        if (!Command.exists ("hamachi"))
        {
            return;
        }
        
        version = retrieve (last_info, "version");
        
        if (version.has_prefix ("hamachi-lnx-"))
        {
            version = version.replace ("hamachi-lnx-", "");
        }
        
        if (version != "")
        {
            Debug.log (Debug.domain.HAMACHI, "Hamachi.determine_version", "Hamachi " + version + " detected");
            return;
        }
        
        string output = Command.return_output ("hamachi -h");
        
        if (output == "")
        {
            output = Command.return_output ("stdbuf -o0 hamachi -h"); // Adjust stdout stream buffering
        }
        
        if (output == "")
        {
            Debug.log (Debug.domain.HAMACHI, "Hamachi.determine_version", "No output");
            return;
        }
        
        if (output == "error")
        {
            Debug.log (Debug.domain.HAMACHI, "Hamachi.determine_version", "Error output");
            return;
        }
        
        Debug.log (Debug.domain.HAMACHI, "Hamachi.determine_version", output);
        
        if (output.contains ("Hamachi, a zero-config virtual private networking utility, ver "))
        {
            try
            {
                MatchInfo mi;
                new Regex ("Hamachi, a zero-config virtual private networking utility, ver (.+)").match (output, 0, out mi);
                
                version = mi.fetch (1);
            }
            catch (RegexError e)
            {
                Debug.log (Debug.domain.ERROR, "Hamachi.determine_version", e.message);
            }
        }
        
        if (version != "")
        {
            Debug.log (Debug.domain.HAMACHI, "Hamachi.determine_version", "Hamachi " + version + " detected");
            return;
        }
        
        Debug.log (Debug.domain.HAMACHI, "Hamachi.determine_version", "Unknown version");
    }
    
    private static void determine_service ()
    {
        if (Command.exists ("systemctl"))
        {
            service = "systemctl {0} logmein-hamachi"; // systemd
        }
        else if (Command.exists ("service"))
        {
            service = "service logmein-hamachi {0}"; // Upstart
        }
        else if (FileUtils.test ("/etc/init.d/logmein-hamachi", GLib.FileTest.EXISTS))
        {
            service = "/etc/init.d/logmein-hamachi {0}"; // SysVinit
        }
        else if (FileUtils.test ("/etc/rc.d/logmein-hamachi", GLib.FileTest.EXISTS))
        {
            service = "/etc/rc.d/logmein-hamachi {0}"; // BSD style init
        }
        
        Debug.log (Debug.domain.ENVIRONMENT, "Hamachi.determine_service", service);
    }
    
    public static string retrieve (string? output, string nfo)
    {
        if (output == null)
        {
            return "";
        }
        
        string retrieved = null;
        
        try
        {
            MatchInfo mi;
            new Regex (nfo + "[ ]*:[ ]+(.+)").match (output, 0, out mi);
            
            retrieved = mi.fetch (1);
        }
        catch (RegexError e)
        {
            Debug.log (Debug.domain.ERROR, "Hamachi.retrieve", e.message);
        }
        
        if (retrieved == null)
        {
            return "";
        }
        
        return retrieved;
    }
    
    public static void configure ()
    {
        string output = Command.return_output (Command.sudo + " " + Command.sudo_args + Command.sudo_start + "bash -c \"echo \'Ipc.User      " + GLib.Environment.get_user_name() + "\' >> " + data_path + "/h2-engine-override.cfg; " + Utils.format (service, "restart", null, null) + "; sleep 1\"");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.configure", output);
    }
    
    public static string start ()
    {
        string output = Command.return_output (Command.sudo + " " + Command.sudo_args + Command.sudo_start + Utils.format (service, "start", null, null));
        Debug.log (Debug.domain.HAMACHI, "Hamachi.start", output);
        
        Thread.usleep (1000000);
        
        return output;
    }
    
    public static string login ()
    {
        string output = Command.return_output ("hamachi login");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.login", output);
        
        return output;
    }
    
    public static string logout ()
    {
        string output = Command.return_output ("hamachi logout");
        
        Debug.log (Debug.domain.HAMACHI, "Hamachi.logout", output);
        return output;
    }
    
    public static string get_account ()
    {
        if (Haguichi.demo_mode)
        {
            return "-";
        }
        
        string output = retrieve (last_info, "lmi account");
        
        Debug.log (Debug.domain.HAMACHI, "Hamachi.get_account", output);
        return output;
    }
    
    public static string get_client_id ()
    {
        if (Haguichi.demo_mode)
        {
            return "090-123-456";
        }
        
        string output = retrieve (last_info, "client id");
        
        Debug.log (Debug.domain.HAMACHI, "Hamachi.get_client_id", output);
        return output;
    }
    
    public static string[] get_address ()
    {
        if (Haguichi.demo_mode)
        {
            ip_version = "Both";
            return new string[] {"25.123.456.78", "2620:9b::56d:f78e"};
        }
        
        string ipv4 = null;
        string ipv6 = null;
        
        string ouput = retrieve (last_info, "address");
        
        try
        {
            MatchInfo mi;
            new Regex ("""^(?<ipv4>[0-9\.]{7,15})?[ ]*(?<ipv6>[0-9a-z\:]+)?$""").match (ouput, 0, out mi);
            
            ipv4 = mi.fetch_named ("ipv4");
            ipv6 = mi.fetch_named ("ipv6");
        }
        catch (RegexError e)
        {
            Debug.log (Debug.domain.ERROR, "Hamachi.get_address", e.message);
        }
        
        if ((ipv4 != "") &&
            (ipv6 != null))
        {
            ip_version = "Both";
        }
        else if (ipv4 != "")
        {
            ip_version = "IPv4";
        }
        else if (ipv6 != null)
        {
            ip_version = "IPv6";
        }
        
        Debug.log (Debug.domain.HAMACHI, "Hamachi.get_address", "IPv4: " + ipv4);
        Debug.log (Debug.domain.HAMACHI, "Hamachi.get_address", "IPv6: " + ipv6);
        
        return new string[] {ipv4, ipv6};
    }
    
    public static string get_info ()
    {
        if ((!Haguichi.demo_mode) &&
            (Command.exists ("hamachi")))
        {
            last_info = Command.return_output ("hamachi");
            Debug.log (Debug.domain.HAMACHI, "Hamachi.get_info", last_info);
        }
        
        return last_info;
    }
    
    public static bool go_online (Network network)
    {
        bool success = true;
        
        if (!Haguichi.demo_mode)
        {
            string output = Command.return_output ("hamachi go-online \"" + Utils.clean_string (network.id) + "\"");
            Debug.log (Debug.domain.HAMACHI, "Hamachi.go_online", output);
            
            if ((output.contains (".. failed")) &&
                (!output.contains (".. failed, already online")))
            {
                success = false;
                
                string heading = Utils.format (Text.failed_go_online_heading, network.name, null, null);
                string message = Text.see_output;
                
                Idle.add_full (Priority.HIGH_IDLE, () =>
                {
                    new Dialogs.Message (Haguichi.window, heading, message, Gtk.MessageType.ERROR, output);
                    return false;
                });
            }
        }
        
        return success;
    }
    
    public static bool go_offline (Network network)
    {
        bool success = true;
        
        if (!Haguichi.demo_mode)
        {
            string output = Command.return_output ("hamachi go-offline \"" + Utils.clean_string (network.id) + "\"");
            Debug.log (Debug.domain.HAMACHI, "Hamachi.go_offline", output);
            
            if ((output.contains (".. failed")) &&
                (!output.contains (".. failed, already offline")))
            {
                success = false;
                
                string heading = Utils.format (Text.failed_go_offline_heading, network.name, null, null);
                string message = Text.see_output;
                
                Idle.add_full (Priority.HIGH_IDLE, () =>
                {
                    new Dialogs.Message (Haguichi.window, heading, message, Gtk.MessageType.ERROR, output);
                    return false;
                });
            }
        }
        
        return success;
    }
    
    public static void delete (Network network)
    {
        string output = Command.return_output ("hamachi delete \"" + Utils.clean_string (network.id) + "\"");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.delete", output);

        if (output.contains (".. failed"))
        {
            string heading = Utils.format (Text.failed_delete_network_heading, network.name, null, null);
            string message = Text.see_output;
            
            Idle.add_full (Priority.HIGH_IDLE, () =>
            {
                new Dialogs.Message (Haguichi.window, heading, message, Gtk.MessageType.ERROR, output);
                return false;
            });
        }
    }
    
    public static void leave (Network network)
    {
        string output = Command.return_output ("hamachi leave \"" + Utils.clean_string (network.id) + "\"");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.leave", output);
        
        if (output.contains (".. failed"))
        {
            string heading = Utils.format (Text.failed_leave_network_heading, network.name, null, null);
            string message = Text.see_output;
            
            Idle.add_full (Priority.HIGH_IDLE, () =>
            {
                new Dialogs.Message (Haguichi.window, heading, message, Gtk.MessageType.ERROR, output);
                return false;
            });
        }
    }
    
    public static void approve (Member member)
    {
        string output = Command.return_output ("hamachi approve \"" + Utils.clean_string (member.network_id) + "\" " + member.client_id);
        Debug.log (Debug.domain.HAMACHI, "Hamachi.approve", output);
    }
    
    public static void reject (Member member)
    {
        string output = Command.return_output ("hamachi reject \"" + Utils.clean_string (member.network_id) + "\" " + member.client_id);
        Debug.log (Debug.domain.HAMACHI, "Hamachi.reject", output);
    }
    
    public static void evict (Member member)
    {
        string output = Command.return_output ("hamachi evict \"" + Utils.clean_string (member.network_id) + "\" " + member.client_id);
        Debug.log (Debug.domain.HAMACHI, "Hamachi.evict", output);

        if (output.contains (".. failed"))
        {
            string heading = Utils.format (Text.failed_evict_member_heading, member.nick, null, null);
            string message = Text.see_output;
            
            Idle.add_full (Priority.HIGH_IDLE, () =>
            {
                new Dialogs.Message (Haguichi.window, heading, message, Gtk.MessageType.ERROR, output);
                return false;
            });
        }
    }
    
    private static string get_list ()
    {
        string output = Command.return_output ("hamachi list");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.get_list", "\n" + output);
        
        return output;
    }
    
    public static string random_address ()
    {
        string address  = "25.";
               address += Random.int_range (1, 255).to_string();
               address += ".";
               address += Random.int_range (1, 255).to_string();
               address += ".";
               address += Random.int_range (1, 255).to_string();
        
        return address;
    }
    
    public static string random_client_id ()
    {
        string id  = "0";
               id += Random.int_range (80, 99).to_string();
               id += "-";
               id += Random.int_range (100, 999).to_string();
               id += "-";
               id += Random.int_range (100, 999).to_string();
        
        return id;
    }
    
    public static string random_network_id ()
    {
        string id  = "0";
               id += Random.int_range (40, 45).to_string();
               id += "-";
               id += Random.int_range (100, 999).to_string();
               id += "-";
               id += Random.int_range (100, 999).to_string();
        
        return id;
    }
    
    public static List<Network> return_list ()
    {
        List<Network> networks = new List<Network>();
        string output = "";
        
        if (Haguichi.demo_mode)
        {
            if (Haguichi.demo_list_path != null)
            {
                output = Command.return_output ("cat " + Haguichi.demo_list_path);
            }
            else
            {
                output += " * [Artwork]  capacity: 3/5, subscription type: Free, owner: ztefn (090-736-821)\n";
                output += "       " + random_client_id() + "   Lapo                       " + random_address() + "  alias: not set                             direct\n";
                output += "     * 090-736-821   ztefn                      " + random_address() + "  alias: not set        2146:0d::987:a654    direct\n";
                output += "   [Bug Hunters]  capacity: 4/5,   [192.168.155.24/24]  subscription type: Free, owner: This computer\n";
                output += "     * " + random_client_id() + "   Conrad                     192.168.155.20  alias: not set                             via relay\n";
                output += "     * " + random_client_id() + "   Eduardo                    192.168.155.21  alias: not set                             direct\n";
                output += "       " + random_client_id() + "   war59312                   192.168.155.22\n";
                output += "     ? " + random_client_id() + " \n";
                output += "       You are approaching your member limit and may soon have to upgrade your network.\n";
                output += " * [" + random_network_id() + "]  Development  capacity: 2/32, subscription type: Standard, owner: ztefn (090-736-821)\n";
                output += "     * 090-736-821   ztefn                      " + random_address() + "  alias: not set        2146:0d::987:a654    direct\n";
                output += "   [" + random_network_id() + "]Packaging  capacity: 4/256, subscription type: Premium, owner: Andrew (094-409-761)\n";
                output += "     * " + random_client_id() + "   lowfatcomputing            " + random_address() + "  alias: not set                             via relay\n";
                output += "     * 094-409-761   Andrew                     " + random_address() + "  alias: not set                             direct\n";
                output += "       " + random_client_id() + "   etamPL                     " + random_address() + "\n";
                output += " * [" + random_network_id() + "]Translators  capacity: 18/256, subscription type: Multi-network, owner: translators@haguichi.net\n";
                output += "     x " + random_client_id() + "   Aytunç                     " + random_address() + "\n";
                output += "     * " + random_client_id() + "   Brbla                      " + random_address() + "  alias: not set                             via relay\n";
                output += "       " + random_client_id() + "   Daniel                     " + random_address() + "\n";
                output += "     ! " + random_client_id() + "   dimitrov                   " + random_address() + "  alias: not set                             IP protocol mismatch between you and peer\n";
                output += "     * " + random_client_id() + "   enricog                    " + random_address() + "  alias: not set                             direct\n";
                output += "     * " + random_client_id() + "   fitoschido                 " + random_address() + "\n";
                output += "     * " + random_client_id() + "   Fedik                      " + random_address() + "  alias: not set                             direct\n";
                output += "     * " + random_client_id() + "   galamarv                   " + random_address() + "  alias: not set                             via relay\n";
                output += "     * " + random_client_id() + "   HeliosReds                 " + random_address() + "  alias: not set                             direct\n";
                output += "     ! " + random_client_id() + "   jmb_kz                     " + random_address() + "  alias: not set                             direct\n";
                output += "     * " + random_client_id() + "   Ḷḷumex03                   " + random_address() + "  alias: not set                             direct\n";
                output += "     * " + random_client_id() + "   Raven46                    " + random_address() + "  alias: not set                             direct\n";
                output += "     * " + random_client_id() + "   Rodrigo                    " + random_address() + "  alias: not set                             direct\n";
                output += "     ! " + random_client_id() + "   scrawl                     " + random_address() + "  alias: 25.353.432.28  2620:9b::753:b470    direct      UDP  170.45.240.141:43667  This address is also used by another peer\n";
                output += "       " + random_client_id() + "   Sergey                     " + random_address() + "\n";
                output += "     x " + random_client_id() + "   Soker                      " + random_address() + "\n";
                output += "     * " + random_client_id() + "   Zdeněk                     " + random_address() + "  alias: not set                             direct\n";
                output += "     * " + random_client_id() + "   ztefn                      " + random_address() + "  alias: not set        2146:0d::987:a654    direct\n";
            }
        }
        else
        {
            output = get_list();
        }
        
        string[] split = output.split ("\n");
        string cur_network_id = "";
        
        try
        {
            Regex network_regex           = new Regex ("""^ (?<status>.{1}) \[(?<id>.+?)\][ ]*(?<name>.*?)[ ]*(capacity: [0-9]+/(?<capacity>[0-9]+),)?[ ]*(\[(?<subnet>[0-9\./]{9,19})\])?[ ]*( subscription type: (?<subscription>[^,]+),)?( owner: (?<owner>.*))?$""");
            Regex normal_member_regex     = new Regex ("""^     (?<status>.{1}) (?<id>[0-9-]{11})[ ]+(?<nick>.*?)[ ]*(?<ipv4>[0-9\.]{7,15})?[ ]*(alias: (?<alias>[0-9\.]{7,15}|not set))?[ ]*(?<ipv6>[0-9a-f\:]+\:[0-9a-f\:]+)?[ ]*(?<connection>direct|via relay|via server)?[ ]*(?<transport>UDP|TCP)?[ ]*(?<tunnel>[0-9\.]+\:[0-9]+)?[ ]*(?<message>[ a-zA-Z]+)?$""");
            Regex unapproved_member_regex = new Regex ("""^     \? (?<id>[0-9-]{11})[ ]*$""");
        
            foreach (string s in split)
            {
                if (s.length > 5) // Check string for minimum chars
                {
                    if (s.index_of ("[") == 3) // Line contains network
                    {
                        MatchInfo mi;
                        network_regex.match (s, RegexMatchFlags.NOTEMPTY, out mi);
                        
                        string id       = mi.fetch_named ("id");
                        string name     = mi.fetch_named ("name").chomp();
                        string owner    = mi.fetch_named ("owner");
                        string capacity = mi.fetch_named ("capacity");
                        Status status   = new Status (mi.fetch_named ("status"));
                        
                        if (name == "")
                        {
                            name = id;
                        }
                        
                        int capacity_int = 0;
                        if (capacity != null)
                        {
                            capacity_int = int.parse (capacity);
                        }
                        
                        Network network = new Network (status, id, name, owner, capacity_int);
                        networks.append (network);
                        
                        cur_network_id = id;
                    }
                    else if (s.index_of ("?") == 5) // Line contains unapproved member
                    {
                        MatchInfo mi;
                        unapproved_member_regex.match (s, RegexMatchFlags.NOTEMPTY, out mi);
                        
                        string id     = mi.fetch_named ("id");
                        string nick   = Text.unknown;
                        Status status = new Status ("?");
                        
                        Member member = new Member (status, cur_network_id, null, null, nick, id, null);
                        
                        foreach (Network network in networks)
                        {
                            if (network.id == cur_network_id)
                            {
                                network.add_member (member);
                            }
                        }
                    }
                    else if (s.index_of ("-") == 10) // Line contains normal member
                    {
                        MatchInfo mi;
                        normal_member_regex.match (s, RegexMatchFlags.NOTEMPTY, out mi);
                        
                        string id         = mi.fetch_named ("id");
                        string nick       = mi.fetch_named ("nick");
                        string ipv4       = mi.fetch_named ("ipv4");
                        string ipv6       = mi.fetch_named ("ipv6");
                        string alias      = mi.fetch_named ("alias");
                        string tunnel     = mi.fetch_named ("tunnel");
                        string connection = mi.fetch_named ("connection");
                        string message    = mi.fetch_named ("message");
                        Status status     = new Status.complete (mi.fetch_named ("status"), connection, message);
                        
                        if ((nick == "") ||
                            (nick == "anonymous"))
                        {
                            nick = Text.anonymous;
                        }
                        
                        if (ipv4 == "")
                        {
                            ipv4 = null;
                        }
                        
                        if (ipv6 == "")
                        {
                            ipv6 = null;
                        }
                        
                        if ((alias != null) &&
                            (alias.contains (".")))
                        {
                            ipv4 = alias;
                            ipv6 = null; // IPv6 address doesn't work when the alias is set, therefore clearing it
                        }
                        
                        if (tunnel == "")
                        {
                            tunnel = null;
                        }
                        
                        Member member = new Member (status, cur_network_id, ipv4, ipv6, nick, id, tunnel);
                        
                        foreach (Network network in networks)
                        {
                            if (network.id == cur_network_id)
                            {
                                network.add_member (member);
                            }
                        }
                    }
                }
            }
        }
        catch (RegexError e)
        {
            Debug.log (Debug.domain.ERROR, "Hamachi.return_list", e.message);
        }
        
        return networks;
    }
    
    public static string set_nick (string nick)
    {
        string output = "";
        
        if ((!Haguichi.demo_mode) &&
            (Controller.last_status >= 6))
        {
            output = Command.return_output ("hamachi set-nick \"" + Utils.clean_string (nick) + "\"");
            Debug.log (Debug.domain.HAMACHI, "Hamachi.set_nick", output);
        }
        
        return output;
    }
    
    public static string set_protocol (string protocol)
    {
        string output = "";
        
        if (!Haguichi.demo_mode)
        {
            output = Command.return_output ("hamachi set-ip-mode \"" + protocol + "\"");
            Debug.log (Debug.domain.HAMACHI, "Hamachi.set_protocol", output);
        }
        
        return output;
    }
    
    public static string attach (string account_id, bool with_networks)
    {
        string output  = "";
        string command = "attach";
        
        if (with_networks)
        {
            command += "-net";
        }
        
        output = Command.return_output ("hamachi " + command + " \"" + Utils.clean_string (account_id) + "\"");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.attach", output);
        
        return output;
    }
    
    public static string join_network (string name, string password)
    {
        string output = Command.return_output ("hamachi do-join \"" + Utils.clean_string (name) + "\" \"" + Utils.clean_string (password) + "\"");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.join_network", output);
        
        return output;
    }
    
    public static string set_access (string network_id, string locking, string approve)
    {
        string output = "";
        
        if (!Haguichi.demo_mode)
        {
            output = Command.return_output ("hamachi set-access \"" + Utils.clean_string (network_id) + "\" " + locking + " " + approve);
            Debug.log (Debug.domain.HAMACHI, "Hamachi.set_access", output);
        }
        
        return output;
    }
    
    public static string set_password (string network_id, string password)
    {
        string output = "";
        
        if (!Haguichi.demo_mode)
        {
            output = Command.return_output ("hamachi set-pass \"" + Utils.clean_string (network_id) + "\" \"" + Utils.clean_string (password) + "\"");
            Debug.log (Debug.domain.HAMACHI, "Hamachi.set_password", output);
        }
        
        return output;
    }
    
    public static string create_network (string name, string password)
    {
        string output = Command.return_output ("hamachi create \"" + Utils.clean_string (name) + "\" \"" + Utils.clean_string (password) + "\"");
        Debug.log (Debug.domain.HAMACHI, "Hamachi.create_network", output);
        
        return output;
    }
    
    public static void save_config (string filename)
    {
        string output = Command.return_output ("tar -cavPf '" + filename + "' " + Hamachi.data_path);
        Debug.log (Debug.domain.INFO, "Hamachi.save_config", output);
    }
    
    public static void restore_config (string filename)
    {
        string output = Command.return_output ("tar -tvf '" + filename + "'");
        Debug.log (Debug.domain.INFO, "Hamachi.restore_config", "Listing archive contents...\n" + output);
        
        if (output.contains (Hamachi.data_path))
        {
            GlobalEvents.stop_hamachi();
            
            output = Command.return_output (Command.sudo + " " + Command.sudo_args + Command.sudo_start + "bash -c \"" + Utils.format (service, "stop", null, null) + "; sleep 1; rm " + Hamachi.data_path + "/*; tar -xavf '" + filename + "' -C /; " + Utils.format (service, "start", null, null) + "; sleep 1\"");
            Debug.log (Debug.domain.INFO, "Hamachi.restore_config", output);
            
            Controller.init();
        }
        else
        {
            Debug.log (Debug.domain.INFO, "Hamachi.restore_config", "Archive doesn't contain " + Hamachi.data_path);
            new Dialogs.Message (Haguichi.window, Text.config_restore_error_title, Text.config_restore_error_message, Gtk.MessageType.ERROR, null);
        }
    }
}
