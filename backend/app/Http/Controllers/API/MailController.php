<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\MailConfiguration;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Webklex\IMAP\Facades\Client;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Mail;

class MailController extends Controller
{
    public function getSettings(Request $request)
    {
        $config = MailConfiguration::where('user_id', $request->user()->id)->first();
        if (!$config) {
            return response()->json(['message' => 'No mail configuration found'], 404);
        }
        return response()->json($config);
    }

    public function storeSettings(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
            'imap_host' => 'required',
            'imap_port' => 'required|integer',
            'smtp_host' => 'required',
            'smtp_port' => 'required|integer',
        ]);

        $config = MailConfiguration::updateOrCreate(
            ['user_id' => $request->user()->id],
            [
                'email' => $request->email,
                'password' => Crypt::encryptString($request->password),
                'imap_host' => $request->imap_host,
                'imap_port' => $request->imap_port,
                'imap_encryption' => $request->imap_encryption ?? 'ssl',
                'smtp_host' => $request->smtp_host,
                'smtp_port' => $request->smtp_port,
                'smtp_encryption' => $request->smtp_encryption ?? 'ssl',
                'display_name' => $request->display_name,
                'signature' => $request->signature,
                'is_active' => true,
            ]
        );


        return response()->json(['message' => 'Settings saved successfully', 'config' => $config]);
    }

    public function testConnection(Request $request)
    {
        $config = MailConfiguration::where('user_id', $request->user()->id)->first();
        if (!$config) {
            return response()->json(['message' => 'Configure your mail first'], 404);
        }

        try {
            $client = Client::make([
                'host'          => $config->imap_host,
                'port'          => $config->imap_port,
                'encryption'    => $config->imap_encryption,
                'validate_cert' => true,
                'username'      => $config->email,
                'password'      => Crypt::decryptString($config->password),
                'protocol'      => 'imap'
            ]);

            $client->connect();
            return response()->json(['message' => 'Connection successful!']);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Connection failed: ' . $e->getMessage()], 500);
        }
    }

    public function getInbox(Request $request)
    {
        $config = MailConfiguration::where('user_id', $request->user()->id)->first();
        if (!$config) return response()->json([], 404);

        try {
            $client = Client::make([
                'host'          => $config->imap_host,
                'port'          => $config->imap_port,
                'encryption'    => $config->imap_encryption,
                'validate_cert' => true,
                'username'      => $config->email,
                'password'      => Crypt::decryptString($config->password),
                'protocol'      => 'imap'
            ]);

            $client->connect();
            $folder = $client->getFolder('INBOX');
            $messages = $folder->query()->limit(20)->get();

            $data = [];
            foreach ($messages as $oMessage) {
                $data[] = [
                    'id' => $oMessage->getUid(),
                    'subject' => $oMessage->getSubject(),
                    'from' => $oMessage->getFrom()[0]->full,
                    'date' => $oMessage->getDate()[0]->format('Y-m-d H:i:s'),
                    'snippet' => substr(strip_tags($oMessage->getTextBody()), 0, 100),
                ];
            }

            return response()->json($data);
        } catch (\Exception $e) {
            return response()->json(['message' => $e->getMessage()], 500);
        }
    }

    public function sendMail(Request $request)
    {
        $request->validate([
            'to' => 'required|email',
            'subject' => 'required',
            'body' => 'required',
        ]);

        $config = MailConfiguration::where('user_id', $request->user()->id)->first();
        if (!$config) return response()->json(['message' => 'No mail config'], 404);

        // Dynamic SMTP configuration
        Config::set('mail.mailers.dynamic', [
            'transport' => 'smtp',
            'host' => $config->smtp_host,
            'port' => $config->smtp_port,
            'encryption' => $config->smtp_encryption,
            'username' => $config->email,
            'password' => Crypt::decryptString($config->password),
            'timeout' => null,
            'local_domain' => env('MAIL_EHLO_DOMAIN'),
        ]);

        try {
            Mail::mailer('dynamic')->raw($request->body, function ($message) use ($request, $config) {
                $message->to($request->to)
                        ->subject($request->subject)
                        ->from($config->email, $config->display_name ?? $request->user()->name);

            });

            return response()->json(['message' => 'Mail sent successfully']);
        } catch (\Exception $e) {
            return response()->json(['message' => $e->getMessage()], 500);
        }
    }
}
