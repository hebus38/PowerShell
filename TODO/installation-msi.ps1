<#
$DATASTAMP = get-date -Format yyyyMMdd
$lOGFILE = '{0}-{1}.log' -f $OUTFILE, $DATASTAMP
$MSIARGs = @(
    "/i"
    ('"{0}"' -f $OUTFILE)
    "/qn"
    "/norestart"
    "/L*v"
    $lOGFILE
)
Start-Process "msiexec.exe" -ArgumentList $MSIARGs -Wait -NoNewWindow 
#>
=========================================================
msiexec /Option <Paramètre requis> [Paramètre facultatif]

Options d'installation

	</package | /i> <Produit.msi>
		Installe ou configure un produit
	/a <Produit.msi>
		Installation administrative - Installe un produit sur
		le réseau
	/j<u|m> <produit.msi> [/t <Liste de transformations>]
		[/g <ID de langue>]
		Publie un produit - m pour tous les utilisateurs,
		u pour l'utilisateur actuel
	</uninstall | /x> <Produit.msi | Code produit>
		Désinstalle le produit

Options d'affichage

	/quiet
		Mode silencieux, aucune interaction avec
		l'utilisateur
	/passive
		Mode automatique - barre de progression
		uniquement
	/q[n|b|r|f]
		Définit le niveau d'interface utilisateur
		n - Pas d'interface utilisateur
		b - IU de base
		r - IU réduite
		f - IU complète (option par défaut)
	/help
		Affiche des informations

Options de redémarrage

	/norestart
		Ne pas redémarrer à la fin de l'installation
	/promptrestart
		Proposer à l'utilisateur de redémarrer si
		nécessaire
	/forcerestart
		Toujours redémarrer l'ordinateur après
		l'installation

Options de journalisation

	/l[i|w|e|a|r|u|c|m|o|p|v|x|+|!|*] <fichier journal>
		i - Messages d'état
		w - Avertissements récupérables
		e - Tous les messages d'erreur
		a - Démarrage des actions
		r - Enregistrements spécifiques à certaines
		    actions
		u - Requêtes de l'utilisateur
		c - Paramètres initiaux de l'interface utilisateur
		m - Mémoire insuffisante ou informations de
		    sortie irrécupérables
		o - Message d'espace disque insuffisant
		p - Propriétés du terminal
		v - Mode documenté
		x - Autres informations de débogage
		+ - Ajouter au fichier journal existant
		! - Forcer l'écriture de chaque ligne dans le
		    journal
		* - Écrire toutes les informations, sauf les
		    options v et x
	/log <Fichier journal>
		Identique à /l* <Fichier journal>

Options de mise à jour

	/update <Mise_à_jour_1.msp>[;Mise_à_jour_2.msp]
		Applique les mises à jour
	/uninstall <Guide du code correctif>[;Update2.msp] /package <Product.msi
		| Code produit>
		Supprimer les mises à jour d'un produit

Options de réparation

	/f[p|e|c|m|s|o|d|a|u|v] <Product.msi | Code produit>
		Répare un produit
		p - uniquement si un fichier est manquant
		o - si un fichier est manquant ou si une version
		    antérieure est installée (option par défaut)
		e - si un fichier est manquant ou si une version
		    égale ou antérieure est installée
		d - si un fichier est manquant ou si une version
		    différente est installée
		c - si un fichier est manquant ou si la somme de
		    contrôle ne correspond pas à la valeur
		    calculée
		a - force la réinstallation de tous les fichiers
		u - toutes les entrées de Registre requises et
		    spécifiques à l'utilisateur
		    (option par défaut)
		m - toutes les entrées de Registre requises et
		    spécifiques à l'ordinateur
		    (option par défaut)
		s - tous les raccourcis existants
		    (option par défaut)
		v - s'exécute depuis la source et remet en
		    mémoire cache le package local

Définition des propriétés publiques

	[PROPERTY=valeur de la propriété]

