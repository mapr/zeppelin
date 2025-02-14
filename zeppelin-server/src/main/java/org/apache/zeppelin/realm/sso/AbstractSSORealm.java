package org.apache.zeppelin.realm.sso;

import com.nimbusds.jwt.JWTClaimsSet;
import org.apache.shiro.authc.AuthenticationException;
import org.apache.shiro.authc.AuthenticationInfo;
import org.apache.shiro.authc.AuthenticationToken;
import org.apache.shiro.authc.SimpleAuthenticationInfo;
import org.apache.shiro.authz.AuthorizationInfo;
import org.apache.shiro.authz.SimpleAuthorizationInfo;
import org.apache.shiro.realm.AuthorizingRealm;
import org.apache.shiro.subject.PrincipalCollection;
import org.apache.shiro.subject.SimplePrincipalCollection;

import java.text.ParseException;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Optional;
import java.util.Set;

/**
 * Base class for authorizing realms whose output is a {@link JWTClaimsSet} which contains
 * a claim returned in {@link SSOConfiguration#getUsernameJwtClaim()}, which is treated as username,
 * and "userRoles" & "groups" claims which are treated as roles.
 * Requires {@link SSOConfiguration#IS_ENABLED} to work.
 * Subclasses must call {@code super(Clazz.class);} in a constructor where Clazz is a related
 * AuthenticationToken class, and implement {@link AbstractSSORealm#getVerifiedJWTClaimsSet(AuthenticationToken)} method
 * @param <T> - related AuthenticationToken implementing class
 */
public abstract class AbstractSSORealm<T extends AuthenticationToken> extends AuthorizingRealm {

  private final Class<T> tokenClass;
  protected SSOConfiguration ssoConfiguration;

  public AbstractSSORealm(Class<T> tokenClass) {
    this.tokenClass = tokenClass;
  }

  protected abstract JWTClaimsSet getVerifiedJWTClaimsSet(T token);

  @Override
  protected void onInit() {
    super.onInit();
    if (!SSOConfiguration.IS_ENABLED) {
      return;
    }
    ssoConfiguration = SSOConfiguration.getInstance();
    setAuthenticationTokenClass(tokenClass);
  }

  @Override
  protected AuthorizationInfo doGetAuthorizationInfo(PrincipalCollection principals) {
    return Optional.ofNullable(principals.oneByType(SSOPrincipal.class))
            .map(p -> new SimpleAuthorizationInfo(p.getRoles()))
            .orElse(null);
  }

  @Override
  @SuppressWarnings("unchecked")
  protected AuthenticationInfo doGetAuthenticationInfo(AuthenticationToken token) throws AuthenticationException {
    return new SimpleAuthenticationInfo(new SimplePrincipalCollection(
            parseSSOPrincipal(getVerifiedJWTClaimsSet((T) token)), getName()),
            token.getCredentials());
  }

  public static SSOPrincipal parseSSOPrincipal(JWTClaimsSet jwtClaimsSet) {
    String usernameClaim = SSOConfiguration.getInstance().getUsernameJwtClaim();
    try {
      String username = jwtClaimsSet.getClaimAsString(usernameClaim);
      Set<String> roles = new HashSet<>();
      Optional.ofNullable(jwtClaimsSet.getStringListClaim("userRoles")).ifPresent(roles::addAll);
      Optional.ofNullable(jwtClaimsSet.getStringListClaim("groups"))
              .ifPresent(jwtGroups -> jwtGroups.forEach(
                      s -> Arrays.stream(s.split("/"))
                              .filter(g -> !g.isEmpty())
                              .forEach(roles::add)));
      return new AbstractSSORealm.SSOPrincipal(username, roles);
    } catch (ParseException e) {
      throw new IllegalStateException("Could not parse JWTClaimsSet into SSOPrincipal", e);
    }
  }

  public static class SSOPrincipal {
    private final String username;
    private final Set<String> roles;

    public SSOPrincipal(String username, Set<String> roles) {
      this.username = username;
      this.roles = roles;
    }

    public String getUsername() {
      return username;
    }

    public Set<String> getRoles() {
      return roles;
    }

    @Override
    public String toString() {
      return username;
    }
  }
}
