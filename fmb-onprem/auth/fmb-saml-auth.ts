
/**
 * FMB On-Premises SAML Authentication
 * Integrates with RSA Identity Provider for on-premises authentication
 */

import passport from 'passport';
import { Strategy as SamlStrategy } from '@node-saml/passport-saml';
import { loadFmbOnPremConfig } from '../config/fmb-env.js';
import { Request, Response } from 'express';

interface SamlUser {
  email: string;
  firstName: string;
  lastName: string;
  department: string;
}

let samlStrategy: SamlStrategy;

export function configureFmbSamlAuth() {
  const config = loadFmbOnPremConfig();
  
  samlStrategy = new SamlStrategy({
    entryPoint: config.saml.ssoUrl,
    issuer: config.saml.entityId,
    cert: config.saml.certificate,
    callbackUrl: config.saml.acsUrl,
    signatureAlgorithm: 'sha256',
    identifierFormat: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    wantAssertionsSigned: true,
    wantAuthnResponseSigned: true,
    acceptedClockSkewMs: 5000,
    attributeConsumingServiceIndex: false,
    disableRequestedAuthnContext: true
  }, async (profile: any, done: Function) => {
    try {
      console.log('🔐 [FMB-SAML] Processing SAML assertion:', JSON.stringify(profile, null, 2));
      
      // Extract user information from SAML assertion
      const email = profile.email || profile['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] || profile.nameID;
      const firstName = profile.firstName || profile['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname'] || 'Unknown';
      const lastName = profile.lastName || profile['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname'] || 'User';
      const department = profile.department || profile['http://schemas.microsoft.com/ws/2008/06/identity/claims/department'] || 'General';
      
      if (!email) {
        console.error('🔴 [FMB-SAML] No email found in SAML assertion');
        return done(new Error('Email is required for authentication'), null);
      }
      
      const user: SamlUser = {
        email,
        firstName,
        lastName,
        department
      };
      
      console.log('✅ [FMB-SAML] User profile extracted:', user);
      return done(null, user);
      
    } catch (error) {
      console.error('🔴 [FMB-SAML] Error processing SAML assertion:', error);
      return done(error, null);
    }
  });
  
  passport.use('fmb-saml', samlStrategy);
  
  return samlStrategy;
}

export async function handleFmbSamlLogin(req: Request, res: Response) {
  console.log('🔐 [FMB-SAML] Initiating SAML login');
  passport.authenticate('fmb-saml')(req, res);
}

export async function handleFmbSamlCallback(req: Request, res: Response) {
  console.log('🔐 [FMB-SAML] Processing SAML callback');
  
  passport.authenticate('fmb-saml', async (err: any, user: SamlUser) => {
    if (err) {
      console.error('🔴 [FMB-SAML] Authentication error:', err);
      return res.redirect('/?error=saml_error');
    }
    
    if (!user) {
      console.error('🔴 [FMB-SAML] No user returned from SAML');
      return res.redirect('/?error=no_user');
    }
    
    try {
      // Store user in session
      req.session.user = {
        id: `fmb-${user.email}`,
        email: user.email,
        name: `${user.firstName} ${user.lastName}`,
        firstName: user.firstName,
        lastName: user.lastName,
        department: user.department,
        profileImageUrl: null,
        role: 'employee' // Default role, will be managed in app
      };
      
      console.log('✅ [FMB-SAML] User authenticated successfully:', user.email);
      res.redirect('/dashboard');
    } catch (error) {
      console.error('🔴 [FMB-SAML] Error storing user session:', error);
      res.redirect('/?error=session_error');
    }
  })(req, res);
}

export function getFmbSamlMetadata(): string {
  if (!samlStrategy) {
    throw new Error('SAML strategy not initialized. Call configureFmbSamlAuth() first.');
  }
  
  return samlStrategy.generateServiceProviderMetadata();
}
