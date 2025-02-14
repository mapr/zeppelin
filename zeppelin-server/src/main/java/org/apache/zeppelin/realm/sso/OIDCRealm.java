package org.apache.zeppelin.realm.sso;

import com.nimbusds.jwt.JWT;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.nimbusds.oauth2.sdk.token.AccessToken;
import com.nimbusds.openid.connect.sdk.Nonce;
import com.nimbusds.openid.connect.sdk.claims.IDTokenClaimsSet;
import com.nimbusds.openid.connect.sdk.validators.AccessTokenValidator;
import org.apache.shiro.authc.AuthenticationException;
import org.apache.shiro.authc.AuthenticationToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * {@link AbstractSSORealm} implementation, whose token is a consolidation of ID token, expected nonce in it
 * and Access token.
 */
public class OIDCRealm extends AbstractSSORealm<OIDCRealm.Token> {

  private static final Logger LOGGER = LoggerFactory.getLogger(OIDCRealm.class);

  public OIDCRealm() {
    super(Token.class);
  }

  @Override
  protected JWTClaimsSet getVerifiedJWTClaimsSet(Token token) {
    try {
      IDTokenClaimsSet idTokenClaimsSet = ssoConfiguration.getIdTokenValidator().validate(token.idToken, token.expectedNonce);
      AccessToken accessToken = token.accessToken;
      AccessTokenValidator.validate(accessToken, ssoConfiguration.getJwsAlgorithm(), idTokenClaimsSet.getAccessTokenHash());
      return SignedJWT.parse(accessToken.getValue()).getJWTClaimsSet();
    } catch (Exception e) {
      String message = "Could not validate OIDCAuthenticationToken";
      LOGGER.error(message, e);
      throw new AuthenticationException(message, e);
    }
  }

  public static class Token implements AuthenticationToken {
    private final JWT idToken;
    private final Nonce expectedNonce;
    private final AccessToken accessToken;

    public Token(JWT idToken, Nonce expectedNonce, AccessToken accessToken) {
      this.idToken = idToken;
      this.expectedNonce = expectedNonce;
      this.accessToken = accessToken;
    }

    @Override
    public Object getPrincipal() {
      return idToken;
    }

    @Override
    public Object getCredentials() {
      return accessToken;
    }
  }
}
