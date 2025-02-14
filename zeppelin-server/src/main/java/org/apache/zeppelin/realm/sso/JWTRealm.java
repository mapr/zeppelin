package org.apache.zeppelin.realm.sso;

import com.nimbusds.jwt.JWT;
import com.nimbusds.jwt.JWTClaimsSet;
import org.apache.shiro.authc.AuthenticationException;
import org.apache.shiro.authc.AuthenticationToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Simple {@link AbstractSSORealm} implementation that accepts just a signed {@link JWT} object
 * as its Token.
 */
public class JWTRealm extends AbstractSSORealm<JWTRealm.Token> {

  private static final Logger LOGGER = LoggerFactory.getLogger(JWTRealm.class);

  public JWTRealm() {
    super(Token.class);
  }

  @Override
  protected JWTClaimsSet getVerifiedJWTClaimsSet(Token token) {
    try {
      return ssoConfiguration.getJwtProcessor().process(token.jwt, null);
    } catch (Exception e) {
      String message = "Could not process JWT";
      LOGGER.error(message, e);
      throw new AuthenticationException(message, e);
    }
  }

  public static class Token implements AuthenticationToken {
    private final JWT jwt;

    public Token(JWT jwt) {
      this.jwt = jwt;
    }

    @Override
    public Object getPrincipal() {
      return jwt;
    }

    @Override
    public Object getCredentials() {
      return jwt;
    }
  }
}
